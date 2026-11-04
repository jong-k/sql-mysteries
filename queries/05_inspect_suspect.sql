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

