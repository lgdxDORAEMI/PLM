import unittest
from datetime import date

from fastapi.testclient import TestClient

from app.api.v1.account import get_account_service
from app.api.v1.care import get_care_service
from app.api.v1.family import get_family_service
from app.core.security import CurrentUser, get_current_user
from app.domains.account.schemas import (
    EntryDestination,
)
from app.domains.account.service import AccountService
from app.domains.account.stub_repository import StubAccountRepository
from app.domains.care.schemas import ConditionWriteKind
from app.domains.care.service import CareService
from app.domains.care.stub_repository import StubCareRepository
from app.domains.family.schemas import HouseholdRequestStatus
from app.domains.family.service import FamilyService
from app.domains.family.stub_repository import StubFamilyRepository
from app.main import app

TARGET_DATE = date(2026, 9, 17)
WIFE_ID = "wife-user"
HUSBAND_ID = "husband-user"


class BackendSkeletonContractTest(unittest.TestCase):
    def setUp(self) -> None:
        self.account_repository = StubAccountRepository()
        self.care_repository = StubCareRepository()
        self.family_repository = StubFamilyRepository()
        self.family_repository.link_for_demo(WIFE_ID, HUSBAND_ID, "남편")
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=WIFE_ID)
        app.dependency_overrides[get_account_service] = lambda: AccountService(
            self.account_repository
        )
        app.dependency_overrides[get_care_service] = lambda: CareService(
            self.care_repository
        )
        app.dependency_overrides[get_family_service] = lambda: FamilyService(
            self.family_repository
        )
        self.client = TestClient(app)

    def tearDown(self) -> None:
        app.dependency_overrides.clear()
        self.client.close()

    def test_openapi_exposes_domain_contracts(self) -> None:
        paths = self.client.get("/openapi.json").json()["paths"]
        expected = {
            "/api/v1/account/bootstrap",
            "/api/v1/account/profile",
            "/api/v1/account/partner-invitations",
            "/api/v1/care/conditions/{target_date}",
            "/api/v1/care/conditions/{target_date}/activities",
            "/api/v1/care/routine-items/{item_id}/execution",
            "/api/v1/care/daily-reports/{target_date}/preview",
            "/api/v1/care/daily-reports/{target_date}/finalize",
            "/api/v1/care/calendar/{month}",
            "/api/v1/family/household-requests",
            "/api/v1/family/notifications",
            "/api/v1/family/motion/consent",
            "/api/v1/family/motion/collection",
        }
        self.assertEqual(expected - paths.keys(), set())

    def test_bootstrap_uses_profile_and_partner_state(self) -> None:
        response = self.client.get("/api/v1/account/bootstrap")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["destination"], EntryDestination.WIFE_PROFILE)

        response = self.client.put(
            "/api/v1/account/profile",
            json={
                "due_date": "2026-12-20",
                "birth_date": "1996-04-12",
                "height_cm": 165,
                "pre_pregnancy_weight_kg": 55,
                "is_first_pregnancy": True,
                "is_multiple_pregnancy": False,
                "allergies": ["갑각류"],
                "medical_conditions": [],
                "medical_note": "",
            },
        )
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["completed"])
        response = self.client.get("/api/v1/account/bootstrap")
        self.assertEqual(response.json()["destination"], EntryDestination.WIFE_HOME)

    def test_condition_report_and_same_day_new_routine_contract(self) -> None:
        condition = {
            "nausea": 2,
            "waist_pain": 4,
            "pelvis_pain": 2,
            "leg_pain": 1,
            "wrist_pain": 1,
            "fatigue": 4,
            "mood": 3,
        }
        path = f"/api/v1/care/conditions/{TARGET_DATE.isoformat()}"
        response = self.client.put(path, json=condition)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["write_kind"], ConditionWriteKind.CREATED)

        response = self.client.put(
            f"{path}/activities", json={"activities": ["장보기", "빨래", "장보기"]}
        )
        self.assertEqual(response.json()["planned_activities"], ["장보기", "빨래"])

        response = self.client.post(
            f"/api/v1/care/daily-reports/{TARGET_DATE.isoformat()}/finalize"
        )
        self.assertTrue(response.json()["finalized"])

        response = self.client.put(path, json={**condition, "fatigue": 5})
        self.assertEqual(
            response.json()["write_kind"], ConditionWriteKind.NEW_ROUTINE_REQUIRED
        )

    def test_household_request_has_only_confirm_and_complete_transitions(self) -> None:
        response = self.client.post(
            "/api/v1/family/household-requests",
            json={
                "target_date": TARGET_DATE.isoformat(),
                "reason": "오늘은 허리 통증이 있는 날이에요.",
                "items": [{"title": "장보기", "helper_info": "우유"}],
            },
        )
        self.assertEqual(response.status_code, 201)
        request_id = response.json()["request_id"]
        initial_notifications = len(
            self.family_repository.list_notifications(HUSBAND_ID)
        )

        app.dependency_overrides[get_current_user] = lambda: CurrentUser(
            id=HUSBAND_ID
        )
        response = self.client.post(
            f"/api/v1/family/household-requests/{request_id}/confirm"
        )
        self.assertEqual(response.json()["status"], HouseholdRequestStatus.CONFIRMED)
        response = self.client.post(
            f"/api/v1/family/household-requests/{request_id}/complete"
        )
        self.assertEqual(response.json()["status"], HouseholdRequestStatus.COMPLETED)
        self.assertEqual(
            len(self.family_repository.list_notifications(HUSBAND_ID)),
            initial_notifications,
        )

    def test_motion_off_preserves_privacy_contract_and_consent_is_separate(self) -> None:
        response = self.client.put(
            "/api/v1/family/motion/collection", json={"enabled": True}
        )
        self.assertEqual(response.status_code, 409)

        response = self.client.put("/api/v1/family/motion/consent")
        self.assertTrue(response.json()["consent_granted"])
        response = self.client.put(
            "/api/v1/family/motion/collection", json={"enabled": True}
        )
        self.assertTrue(response.json()["collection_enabled"])
        response = self.client.put(
            "/api/v1/family/motion/collection", json={"enabled": False}
        )
        self.assertFalse(response.json()["collection_enabled"])
        self.assertTrue(response.json()["consent_granted"])

        response = self.client.delete("/api/v1/family/motion/consent")
        self.assertFalse(response.json()["consent_granted"])
        self.assertFalse(response.json()["collection_enabled"])
