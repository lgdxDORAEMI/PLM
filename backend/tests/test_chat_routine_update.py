"""S8 챗봇 컨디션 확인과 비차단 웬즈데이 재생성 상태 테스트."""

import unittest
from datetime import date, datetime, timezone

from app.domains.care.schemas import ConditionInput, ConditionResponse, ConditionWriteKind
from app.domains.chat.schemas import (
    ConditionChange,
    RoutineUpdateDecision,
    RoutineUpdateState,
    RoutineUpdateStatus,
)
from app.domains.chat.service import (
    ChatService,
    CONDITION_UPDATE_FAILED,
    ROUTINE_UPDATE_FAILED,
)

TODAY = date(2026, 9, 23)
USER = "wife-1"
JOB = "assistant-message-1"


class FakeChatRepository:
    def __init__(self) -> None:
        self.state = RoutineUpdateState(
            job_id=JOB,
            status=RoutineUpdateStatus.AWAITING_CONFIRMATION,
            summary="피로도를 5단계로 수정합니다.",
            changes=[ConditionChange(field="fatigue", value=5)],
        )

    def get_routine_update(self, user_id, target_date, message_id):
        assert (user_id, target_date, message_id) == (USER, TODAY, JOB)
        return self.state

    def set_routine_update_status(
        self, user_id, target_date, message_id, status, *,
        error_message=None, routine_revision=None,
    ):
        self.state = self.state.model_copy(update={
            "status": status,
            "error_message": error_message,
            "routine_revision": routine_revision,
        })
        return self.state


class FakeCareService:
    def __init__(self) -> None:
        self.current = ConditionResponse(
            nausea=2,
            waist_pain=2,
            pelvis_pain=2,
            leg_pain=2,
            wrist_pain=2,
            fatigue=2,
            mood=4,
            target_date=TODAY,
            planned_activities=[],
            changed_fields=[],
            write_kind=ConditionWriteKind.UPDATED,
            updated_at=datetime.now(timezone.utc),
        )
        self.saved: ConditionInput | None = None

    def get_condition(self, user_id, target_date):
        return self.current

    def save_condition(self, user_id, target_date, payload):
        self.saved = payload
        return self.current


class RoutineUpdateTest(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self.repository = FakeChatRepository()
        self.service = ChatService(self.repository)
        self.care = FakeCareService()

    async def test_confirm_queues_then_regenerates_without_changing_mood(self) -> None:
        queued, should_start = self.service.decide_routine_update(
            USER, TODAY, JOB, RoutineUpdateDecision.CONFIRM
        )
        self.assertTrue(should_start)
        self.assertEqual(queued.status, RoutineUpdateStatus.QUEUED)

        async def regenerate():
            return {"source": "ai", "revision": 2}

        await self.service.run_routine_update(
            USER, TODAY, JOB, self.care, regenerate
        )
        self.assertEqual(self.care.saved.fatigue, 5)
        self.assertEqual(self.care.saved.mood, 4)
        self.assertEqual(self.repository.state.status, RoutineUpdateStatus.SUCCEEDED)
        self.assertEqual(self.repository.state.routine_revision, 2)

    async def test_failed_regeneration_keeps_retryable_failed_status(self) -> None:
        self.service.decide_routine_update(
            USER, TODAY, JOB, RoutineUpdateDecision.CONFIRM
        )

        async def regenerate():
            return {"source": "fallback_prev", "revision": 2}

        await self.service.run_routine_update(
            USER, TODAY, JOB, self.care, regenerate
        )
        self.assertEqual(self.repository.state.status, RoutineUpdateStatus.FAILED)
        self.assertEqual(self.repository.state.error_message, ROUTINE_UPDATE_FAILED)
        retried, should_start = self.service.decide_routine_update(
            USER, TODAY, JOB, RoutineUpdateDecision.CONFIRM
        )
        self.assertTrue(should_start)
        self.assertEqual(retried.status, RoutineUpdateStatus.QUEUED)

    async def test_cancel_does_not_start_background_work(self) -> None:
        cancelled, should_start = self.service.decide_routine_update(
            USER, TODAY, JOB, RoutineUpdateDecision.CANCEL
        )
        self.assertFalse(should_start)
        self.assertEqual(cancelled.status, RoutineUpdateStatus.CANCELLED)

    async def test_condition_save_failure_does_not_claim_it_was_saved(self) -> None:
        class BrokenCare(FakeCareService):
            def get_condition(self, user_id, target_date):
                raise RuntimeError("storage down")

        self.service.decide_routine_update(
            USER, TODAY, JOB, RoutineUpdateDecision.CONFIRM
        )

        async def regenerate():
            self.fail("컨디션 저장 실패 뒤에는 루틴을 호출하면 안 됩니다.")

        await self.service.run_routine_update(
            USER, TODAY, JOB, BrokenCare(), regenerate
        )
        self.assertEqual(self.repository.state.status, RoutineUpdateStatus.FAILED)
        self.assertEqual(self.repository.state.error_message, CONDITION_UPDATE_FAILED)


if __name__ == "__main__":
    unittest.main()
