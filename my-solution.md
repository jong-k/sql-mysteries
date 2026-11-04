# 풀이 과정

## 초기 단서

- 범죄 현장 보고서(crime scene report)를 찾아야 한다.
- 이 범죄는 2018년 1월 15일 어느 시점에 발생한 살인 사건이며, SQL 시티에서 일어났다.

## 데이터베이스 확인하기

테이블 및 뷰 목록과 생성 DDL을 확인한다.

```sqlite
-- 테이블 및 뷰 목록과 생성 DDL 확인
SELECT type, name, sql
FROM sqlite_schema
WHERE type IN ('table', 'view')
  AND name NOT LIKE 'sqlite_%' -- sqlite_로 시작하는 SQLite 내부 시스템 테이블을 결과에서 제외
ORDER BY type, name;
```

crime_scene_report 테이블이 있어서 이 테이블을 확인한다.

## 범죄 현장 보고서 테이블 확인

먼저 테이블 컬럼 정보와 제약조건을 확인한다.

```sqlite
PRAGMA table_info('crime_scene_report');
```

전체 행 수를 확인한다.

```sqlite
SELECT count(*)
FROM crime_scene_report;
```

데이터 일부를 확인한다.
```sqlite
SELECT *
FROM crime_scene_report
LIMIT 5;
```

테이블을 파악했으니 이제 단서를 기준으로 쿼리를 만들어본다.
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

date 컬럼은 문자열이 아니라 integer 타입이고 yyyymmdd 형식으로 저장되어 있다. 그래서 따옴표 없이 숫자 20180115로 비교한다.

쿼리 결과 1건의 데이터가 있다.
- 목격자 2명
  - 1번째 목격자: Northwestern Dr의 끝 집에 거주
  - 2번째 목격자: 이름 Annabel. Franklin Ave 어딘가에 거주

## 주민 테이블 확인

person 테이블을 확인해본다.
- name(이름), address_number(주소 번호), address_street_name(주소명) 같은 컬럼이 있어서 이걸 활용해서 목격자 정보를 불러올 수 있을 것 같다.
- address_street_name = 'Northwestern Dr'이고 address_number 값이 가장 큰 하나이면서
- name = 'Annabel'이고 address_street_name = 'Franklin Ave'

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
WHERE name LIKE 'Annabel%'
  AND address_street_name = 'Franklin Ave';
```

왜 CTE를 썼나
- 두 목격자는 조건이 완전히 달라서 각각 조회한 뒤 UNION ALL로 합쳐야 한다.
- 그런데 SQLite는 UNION ALL로 합쳐지는 각 SELECT에 ORDER BY나 LIMIT을 따로 붙이지 못한다. 맨 끝에 한 번만 붙일 수 있고, 그러면 합친 결과 전체에 적용된다.
- "번지가 가장 큰 1건"은 첫 번째 목격자에게만 적용해야 하므로, 그 부분을 CTE(last_address)로 먼저 고정하고 합쳤다.

왜 UNION이 아니라 UNION ALL인가
- UNION은 중복 행을 제거하느라 정렬 비용이 든다. 두 목격자는 서로 다른 사람이라 중복이 생길 수 없으므로 UNION ALL이면 충분하다.

LIKE 패턴
- 이름 전체를 모르고 "Annabel"이라는 이름만 알고 있다. 성은 뒤에 붙으니 'Annabel%'로 앞부분만 맞춘다.
- person 테이블에는 Annabell로 시작하는 사람이 3명 더 있다. 이 쿼리에서는 address_street_name = 'Franklin Ave' 조건이 이들을 걸러준다.

쿼리 결과 2명의 주민 데이터가 조회된다.

이제 이 2명의 데이터로 interview 테이블을 뒤져본다.

## 인터뷰 테이블 확인

2명의 주민 번호를 기반으로 interview 테이블에서 정보를 찾을 수 있다.

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

왜 JOIN을 썼나
- interview 테이블에는 person_id와 transcript만 있다. 이름을 같이 보려면 person 쪽 데이터와 엮어야 한다.
- 전체 interview에서 목격자 2명의 것만 남기려면, 앞 단계 결과(witness)와 INNER JOIN하면 된다. INNER JOIN은 양쪽에 모두 있는 행만 남기므로 WHERE person_id IN (...)과 같은 효과를 내면서 이름 컬럼까지 가져온다.
- 쿼리에는 INNER를 생략하고 JOIN이라고만 썼다. SQL에서 JOIN만 쓰면 INNER JOIN을 뜻한다. 이 글의 JOIN은 모두 INNER JOIN이다.

왜 서브쿼리로 한 번 더 감쌌나
- 앞 쿼리의 CTE 내용을 그대로 witness CTE 안으로 옮겼다. CTE 안에서도 UNION ALL 규칙은 같아서, ORDER BY와 LIMIT이 붙은 SELECT는 괄호로 감싸 서브쿼리로 만들어야 한다.

쿼리 결과(목격자 진술)를 토대로 단서를 정리해보면
- 범인은 Get Fit Now Gym 가방을 소지했으며 48Z로 시작하는 멤버십 번호였음. gold 회원 전용 가방이었음. 차량 번호판에 H42W가 포함되어 있었음.
- 범인은 1월 9일에 헬스장에 있었다.

## 헬스장 회원 명부, 체크인 기록, 운전면허 테이블 확인

차량 번호를 차치하고, 위의 단서대로 헬스장 회원 명부, 체크인 테이블을 확인한다.

```sqlite
WITH suspect AS (SELECT *
                 FROM get_fit_now_member m
                          JOIN get_fit_now_check_in c ON m.id = c.membership_id
                 WHERE m.membership_status = 'gold'
                   AND m.id LIKE '48Z%'
                   AND c.check_in_date = 20180109)
SELECT *
FROM suspect;
```

왜 JOIN을 썼나
- 회원 등급(gold)과 회원 번호(48Z)는 get_fit_now_member에 있고, 체크인 날짜는 get_fit_now_check_in에 있다. 세 조건을 한 번에 걸려면 두 테이블을 membership_id로 엮어야 한다.

결과는 2명이다. 이제 차량 번호까지 확인해서 좁히면 된다.

운전면허 테이블에서 차량 번호를 확인하고, 이를 주민 테이블과 엮어서 확인하면 주민 번호를 얻을 수 있다. 이 주민 번호를 헬스장 회원 명부에서 확인하면 된다.

```sqlite
WITH suspect1 AS (SELECT *
                  FROM get_fit_now_member m
                           JOIN get_fit_now_check_in c ON m.id = c.membership_id
                  WHERE m.membership_status = 'gold'
                    AND m.id LIKE '48Z%'
                    AND c.check_in_date = 20180109),
     suspect2 AS (SELECT p.id
                  FROM drivers_license d
                           JOIN person p ON d.id = p.license_id
                  WHERE d.plate_number LIKE '%H42W%')
SELECT s1.person_id, s1.name
FROM suspect1 s1
         JOIN suspect2 s2 ON s1.person_id = s2.id;
```

왜 CTE를 두 개로 나눴나
- 헬스장 단서(suspect1)와 번호판 단서(suspect2)는 서로 다른 테이블에서 나온다. 각각 용의자 목록을 만든 뒤 교집합을 구하는 구조가 단서 정리 순서와 같아서 읽기 쉽다.
- 두 CTE를 person id로 INNER JOIN하면 양쪽에 모두 있는 사람만 남는다. 이것이 교집합이다.

suspect2에서 person을 JOIN한 이유
- 번호판은 drivers_license에만 있고, 헬스장 회원 명부에는 person_id만 있다. drivers_license.id와 person.license_id를 엮어야 면허 소유자의 person id가 나온다. 이 JOIN이 없으면 두 단서를 연결할 열쇠가 없다.

중간 결과
- 헬스장 조건: 2명
- 번호판에 H42W 포함: 3명
- 교집합: 1명

결과 컬럼을 SELECT * 대신 person_id, name으로 적은 이유
- 두 CTE를 JOIN하면 회원 번호 id(48Z55)와 person id(67318)가 둘 다 id라는 이름으로 나와서 헷갈린다. 필요한 컬럼만 적었다.

범인이 도출됐다.

정답이면 사건의 진범을 더 파헤쳐보라는 결과가 나온다. 범인의 인터뷰 기록을 살펴보라는 단서가 주어진다.

## 진범 찾기

범인의 인터뷰에 따르면, 진범은
- 여성
- 키가 65~67인치
- 빨간 머리
- 테슬라 모델 S 소유
- 2017년 12월 SQL 심포니 콘서트에 3번 참여

```sqlite
WITH tesla_owner AS (SELECT p.*
                     FROM drivers_license d
                              JOIN person p ON d.id = p.license_id
                     WHERE d.height BETWEEN 65 AND 67
                       AND d.gender = 'female'
                       AND d.hair_color = 'red'
                       AND d.car_make = 'Tesla'
                       AND d.car_model = 'Model S'),
     participant AS (SELECT f.person_id AS id
                     FROM facebook_event_checkin f
                     WHERE f.event_name = 'SQL Symphony Concert'
                       AND f.date BETWEEN 20171201 AND 20171231
                     GROUP BY f.person_id
                     HAVING count(*) = 3)

SELECT t.id, t.name
FROM tesla_owner t
         JOIN participant p on t.id = p.id;
```

구조는 앞 단계와 같다. 외모와 차량 단서(tesla_owner), 콘서트 단서(participant)를 각각 CTE로 만들고 person id로 JOIN해서 교집합을 구한다.

tesla_owner에서 person을 JOIN한 이유
- 외모와 차량 정보는 drivers_license에 있고 이름은 person에 있다. 최종 결과에 이름을 보여주고 participant와 person id로 엮으려면 JOIN이 필요하다.

participant에서는 person을 JOIN하지 않은 이유
- facebook_event_checkin.person_id가 이미 person.id 값이다. 이름은 tesla_owner 쪽에서 가져오므로 여기서 person을 또 읽을 이유가 없다.

왜 GROUP BY와 HAVING을 썼나
- "3번 참여"는 체크인 행의 개수다. 행 개수를 세려면 person_id로 묶고(GROUP BY) count(*)를 구해야 한다.
- 집계 결과에 조건을 거는 절은 WHERE가 아니라 HAVING이다. WHERE는 묶기 전 각 행에, HAVING은 묶은 뒤 각 그룹에 적용된다.
- 단서가 정확히 3번이라 count(*) = 3으로 썼다. 12월에 3번 이상 참석한 사람은 2명인데, tesla_owner 조건과 교집합을 구하면 1명만 남는다.

날짜 범위
- date 컬럼이 yyyymmdd 정수라서 BETWEEN 20171201 AND 20171231로 12월 전체를 잡을 수 있다.

중간 결과
- 외모와 차량 조건: 3명
- 콘서트 3번 참여: 2명
- 교집합: 1명

## 정답 확인

정답은 사이트 안내대로 solution 테이블에 INSERT한 뒤 SELECT로 확인한다.

```sqlite
INSERT INTO solution
VALUES (1, '용의자 이름');
SELECT value
FROM solution;
```

INSERT만 했는데 SELECT 결과가 정답 여부 메시지로 바뀌어 있다. solution 테이블에 AFTER INSERT 트리거(check_solution)가 걸려 있기 때문이다. 트리거는 새로 들어온 값을 정답과 비교해서 테이블 내용을 지우고 결과 메시지 한 줄로 바꿔 넣는다. 트리거는 sqlite_schema에서 type = 'trigger'로 조회하면 볼 수 있는데, 처음 DB를 둘러볼 때 테이블과 뷰만 조회해서 눈에 띄지 않았다.
