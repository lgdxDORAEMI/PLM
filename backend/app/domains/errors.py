"""도메인 Service가 HTTP 계층에 의존하지 않고 전달하는 공통 오류."""


class DomainNotFoundError(Exception):
    """요청한 도메인 리소스가 없거나 현재 사용자에게 보이지 않는다."""


class DomainConflictError(Exception):
    """현재 상태에서 요청한 상태 전이가 허용되지 않는다."""


class DomainForbiddenError(Exception):
    """현재 사용자에게 요청한 리소스의 읽기 또는 변경 권한이 없다."""


class DomainStorageError(Exception):
    """저장소 연결 또는 요청이 실패했다(예: Supabase 장애)."""
