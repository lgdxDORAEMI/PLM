"""로컬 식사 사진을 Supabase Storage의 meal-images 버킷에 업로드한다."""

from __future__ import annotations

import argparse
from pathlib import Path

from dotenv import dotenv_values
from supabase import create_client

ROOT = Path(__file__).resolve().parents[2]
IMAGE_ROOT = ROOT / "supabase" / "storage" / "meal-images"
ENV_PATH = ROOT / "backend" / ".env"
BUCKET = "meal-images"


def _settings() -> tuple[str, str]:
    values = dotenv_values(ENV_PATH)
    url = (values.get("SUPABASE_URL") or "").strip()
    key = (values.get("SUPABASE_SERVICE_ROLE_KEY") or "").strip()
    if not url or not key:
        raise SystemExit(
            "backend/.env에 SUPABASE_URL과 SUPABASE_SERVICE_ROLE_KEY가 필요합니다."
        )
    return url, key


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="업로드하지 않고 대상 경로만 확인합니다.",
    )
    args = parser.parse_args()
    files = sorted(IMAGE_ROOT.rglob("*.jpg"))
    if len(files) != 20:
        raise SystemExit(f"식사 사진은 20장이어야 합니다. 현재 {len(files)}장입니다.")

    if args.dry_run:
        for path in files:
            print(path.relative_to(IMAGE_ROOT).as_posix())
        return

    url, key = _settings()
    bucket = create_client(url, key).storage.from_(BUCKET)
    for path in files:
        object_path = path.relative_to(IMAGE_ROOT).as_posix()
        bucket.upload(
            path=object_path,
            file=path.read_bytes(),
            file_options={
                "content-type": "image/jpeg",
                "cache-control": "3600",
                "upsert": "true",
            },
        )
        print(f"uploaded: {object_path}")


if __name__ == "__main__":
    main()
