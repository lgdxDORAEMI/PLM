# 임산부 생활루틴 지식 적재

이 도구는 제공된 생활루틴 자료를 정리·번역·분할하고 임베딩을 만들어 Supabase의 `pregnancy_knowledge` 테이블에 올립니다. 웬즈데이 루틴 생성의 검색 자료를 준비하는 오프라인 데이터 파이프라인입니다.

## 구성

| 파일 | 역할 |
| --- | --- |
| `01_create_pregnancy_knowledge.sql` | pgvector 테이블·검색 함수·인덱스 정의 |
| `02_translate_chunk_embed_upload.py` | 번역, 한국어 분할, 임베딩, 업로드 단계 |
| `pregnancy_knowledge_staging.jsonl` 및 `pregnancy_knowledge_ko.jsonl` | 중간 데이터 |
| `pregnancy_knowledge_supabase.jsonl` | 업로드 데이터 |
| `.env.example`, `requirements.txt` | 도구 설정과 의존성 예시 |

기본 임베딩 모델은 `text-embedding-3-small`이며 SQL은 1536차원 벡터를 사용합니다. 주수 범위는 자료의 임신 단계에 맞춰 기록합니다. 서버 비밀 키는 이 로컬 적재 도구에서만 사용하고 Flutter 앱에 넣지 않습니다.

실행 명령과 환경 설정은 [guide.md](../../guide.md), 앱에서 사용하는 루틴 흐름은 [backend README](../../backend/README.md)를 참고하세요.
