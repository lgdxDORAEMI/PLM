-- backend(service role)가 public 테이블·함수에 접근할 권한 (2026-09-16).
-- 이 프로젝트는 service_role에 기본 GRANT가 없어 PostgREST가 42501(permission denied)을 냈다.
-- RLS는 켜져 있고 정책이 없으므로 anon/authenticated는 여전히 차단된다. service_role은 RLS를 우회한다.
grant usage on schema public to service_role;
grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;
grant execute on all functions in schema public to service_role;

-- 앞으로 만드는 테이블·함수에도 자동 적용.
alter default privileges in schema public grant all on tables to service_role;
alter default privileges in schema public grant all on sequences to service_role;
alter default privileges in schema public grant execute on functions to service_role;
