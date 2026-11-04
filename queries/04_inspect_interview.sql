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