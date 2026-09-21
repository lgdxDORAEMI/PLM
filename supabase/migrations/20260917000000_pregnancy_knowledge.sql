-- RAG 지식 테이블 (W-HOME-001 B③ 검색용). 원본: tools/rag_ingest/01_create_pregnancy_knowledge.sql (팀원 작성, 2026-09-16).
-- 적재는 tools/rag_ingest/02_translate_chunk_embed_upload.py로 한다. 임베딩 모델 text-embedding-3-small → vector(1536).
-- 접근은 backend(service role)만. 다른 테이블과 같이 RLS 켜고 정책 없음.

-- Supabase SQL Editor에서 실행
create extension if not exists vector;

create table if not exists public.pregnancy_knowledge (
  id bigint primary key,
  category text not null,
  week_start smallint null check (week_start between 1 and 40),
  week_end smallint null check (week_end between 1 and 40),
  content text not null,
  source text not null,
  embedding vector(1536)
);

create index if not exists pregnancy_knowledge_week_idx
on public.pregnancy_knowledge (week_start, week_end);

create index if not exists pregnancy_knowledge_category_idx
on public.pregnancy_knowledge (category);

-- 데이터가 충분히 쌓인 뒤 생성 권장
create index if not exists pregnancy_knowledge_embedding_hnsw
on public.pregnancy_knowledge
using hnsw (embedding vector_cosine_ops);

create or replace function public.match_pregnancy_knowledge(
  query_embedding vector(1536),
  match_count int default 5,
  filter_week int default null,
  filter_category text default null
)
returns table (
  id bigint,
  category text,
  week_start smallint,
  week_end smallint,
  content text,
  source text,
  similarity float
)
language sql
stable
as $$
  select
    pk.id,
    pk.category,
    pk.week_start,
    pk.week_end,
    pk.content,
    pk.source,
    1 - (pk.embedding <=> query_embedding) as similarity
  from public.pregnancy_knowledge pk
  where
    pk.embedding is not null
    and (
      filter_week is null
      or pk.week_start is null
      or pk.week_end is null
      or filter_week between pk.week_start and pk.week_end
    )
    and (
      filter_category is null
      or pk.category ilike '%' || filter_category || '%'
    )
  order by pk.embedding <=> query_embedding
  limit match_count;
$$;

alter table public.pregnancy_knowledge enable row level security;
