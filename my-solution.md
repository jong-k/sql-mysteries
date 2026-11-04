# 풀이 과정

## 초기 단서

- 범죄 현장 보고서(crime scene report)를 찾아야 한다.
- 이 범죄는 2018년 1월 15일 어느 시점에 발생한 살인 사건이며, SQL 시티에서 일어났다.

## 데이터베이스 확인하기

테이블 및 뷰 목록과 생성 DDL을 확인한다

### 01_schema_overview.sql

```sqlite
-- 테이블 및 뷰 목록과 생성 DDL 확인
SELECT type, name, sql
FROM sqlite_schema
WHERE type IN ('table', 'view')
  AND name NOT LIKE 'sqlite_%' -- sqlite_로 시작하는 SQLite 내부 시스템 테이블을 결과에서 제외
ORDER BY type, name;
```

crime_scene_report 테이블이 있어서 이 테이블을 확인한다

## 범죄 현장 보고서 테이블 확인

먼저 테이블 컬럼 정보와 제약조건을 확인한다

```sqlite
PRAGMA table_info('crime_scene_report');
```

전체 행 수를 확인

```sqlite
SELECT count(*)
FROM crime_scene_report;
```

데이터 일부 확인
```sqlite
SELECT *
FROM crime_scene_report
LIMIT 5;
```

테이블을 파악했으니 이제 단서를 기준으로 쿼리를 만들어본다
- type = 'murder'
- city = 'SQL City'
- date = 20180115

```sqlite
SELECT *
FROM crime_scene_report
WHERE type = 'murder'
  AND city = 'SQL City'
  AND date = 20180115;
```

쿼리 결과 1건의 데이터가 있다
- 목격자 2명
  - 1번째 목격자: Northwestern Dr의 끝 집에 거주
  - 2번째 목격자: 이름 Annabel. Franklin Ave 어딘가에 거주

## 주민 테이블 확인

person 테이블을 확인해본다
- name(이름), address_number(주소 번호), address_street_name(주소명) 같은 컬럼이 있어서 이걸 활용해서 목격자 정보를 불러올 수 있을 것 같다
- address_street_name = 'Northwestern Dr' 이고 address_number 값이 가장 큰 하나이면서
- name = 'Annabel' 이고 address_street_name = 'Franklin Ave'

```sqlite
WITH last_address AS (SELECT *
                      FROM person
                      WHERE address_street_name = 'Northwestern Dr'
                      ORDER BY address_number DESC
                      LIMIT 1)
SELECT *
FROM last_address
UNION ALL
SELECT *
FROM person
WHERE name LIKE '%Annabel%'
  AND address_street_name = 'Franklin Ave';
```
쿼리 결과 2명의 주민 데이터가 조회된다.

이제 이 2명의 데이터로 interview 테이블을 뒤져본다.

## 인터뷰 테이블 확인

2명의 주민 번호를 기반으로 interview 테이블에서 정보를 찾을 수 있다

```sqlite
WITH witness AS (SELECT *
                 FROM (SELECT *
                       FROM person
                       WHERE address_street_name = 'Northwestern Dr'
                       ORDER BY address_number DESC
                       LIMIT 1)
                 UNION ALL
                 SELECT *
                 FROM person
                 WHERE name LIKE 'Annabel%'
                   AND address_street_name = 'Franklin Ave')
SELECT w.name, i.*
FROM interview i
         JOIN witness w on i.person_id = w.id;
```

쿼리 결과(목격자 진술)를 토대로 단서를 정리해보면
- 범인은 Get Fit Now Gym 가방을 소지했으며 48Z로 시작하는 멤버십 번호였음. gold 회원 전용 가방이었음. 차량 번호판에 H42W 가 포함되어 있었음
- 범인은 1월 9일에 헬스장에 있었다

## 