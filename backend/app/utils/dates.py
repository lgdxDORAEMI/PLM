from datetime import date, datetime, timedelta, timezone

# 한국은 서머타임이 없어 고정 오프셋을 쓴다. zoneinfo는 Windows에서 tzdata 설치가 필요하다.
KST = timezone(timedelta(hours=9))

# 임신 기간(마지막 생리 시작일 → 출산예정일).
FULL_TERM_DAYS = 280


def today_kst() -> date:
    return datetime.now(KST).date()


def pregnancy_age(due_date: date, today: date) -> tuple[int, int]:
    """출산예정일 기준 임신 (주, 일). 임신 시작일 = 출산예정일 - 280일."""
    start = due_date - timedelta(days=FULL_TERM_DAYS)
    weeks, days = divmod(max((today - start).days, 0), 7)
    return weeks, days
