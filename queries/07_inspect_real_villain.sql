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
