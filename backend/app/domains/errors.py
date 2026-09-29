"""도메인 Service가 HTTP 계층에 의존하지 않고 전달하는 공통 오류."""


# 09-29: 연동됐지만 아내가 초기화 후 다시 공개하지 않았을 때의 403 detail.
# 프론트가 이 문구로 "아내의 프로필 정보가 없습니다" 화면을 고른다(api_client.dart).
PARTNER_NOT_SHARED = "아내가 아직 기록을 공개하지 않았습니다."


class DomainNotFoundError(Exception):
    """요청한 도메인 리소스가 없거나 현재 사용자에게 보이지 않는다."""


class DomainConflictError(Exception):
    """현재 상태에서 요청한 상태 전이가 허용되지 않는다."""


class DomainForbiddenError(Exception):
    """현재 사용자에게 요청한 리소스의 읽기 또는 변경 권한이 없다."""


class DomainStorageError(Exception):
    """저장소 연결 또는 요청이 실패했다(예: Supabase 장애)."""
