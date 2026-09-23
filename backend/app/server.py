import os

import uvicorn


DEFAULT_PORT = 8000


def server_port() -> int:
    """Railway가 주입한 PORT를 검증하고 로컬 기본 포트를 반환한다."""
    raw_port = os.getenv("PORT", str(DEFAULT_PORT))
    try:
        return int(raw_port)
    except ValueError as exc:
        raise RuntimeError("PORT는 정수여야 합니다.") from exc


def main() -> None:
    """셸 변수 확장 없이 운영용 Uvicorn 서버를 시작한다."""
    uvicorn.run("app.main:app", host="0.0.0.0", port=server_port())


if __name__ == "__main__":
    main()
