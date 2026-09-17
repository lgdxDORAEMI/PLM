"""도메인 오류를 일관된 HTTP 응답으로 변환한다."""

from fastapi import HTTPException, status

from app.domains.errors import (
    DomainConflictError,
    DomainForbiddenError,
    DomainNotFoundError,
)


def to_http_exception(error: Exception) -> HTTPException:
    if isinstance(error, DomainNotFoundError):
        return HTTPException(status.HTTP_404_NOT_FOUND, str(error))
    if isinstance(error, DomainConflictError):
        return HTTPException(status.HTTP_409_CONFLICT, str(error))
    if isinstance(error, DomainForbiddenError):
        return HTTPException(status.HTTP_403_FORBIDDEN, str(error))
    raise error
