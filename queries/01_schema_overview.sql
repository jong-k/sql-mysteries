-- 테이블 및 뷰 목록과 생성 DDL 확인
SELECT type, name, sql
FROM sqlite_schema
WHERE type IN ('table', 'view')
  AND name NOT LIKE 'sqlite_%' -- sqlite_로 시작하는 SQLite 내부 시스템 테이블을 결과에서 제외
ORDER BY type, name;
