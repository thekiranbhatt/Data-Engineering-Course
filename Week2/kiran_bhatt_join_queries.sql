---Assignment Week 2: ON Joins and New schema----
---Student : Kiran Bhatt


-------------- Query 1------------------
-- Completed rides per driver, name and count desc. (Join and Group by)

SELECT 
    d.name AS driver_name,
    COUNT(t.trip_id) AS completed_rides_count
FROM 
    drivers d
INNER JOIN 
    trips t ON d.driver_id = t.driver_id
WHERE 
    t.status = 'completed'
GROUP BY 
    d.driver_id, 
    d.name
ORDER BY 
    completed_rides_count DESC;


---------------- Query 2 ------------------
-- Drivers with NO completed rides (Anti-join pattern)
SELECT 
    d.driver_id,
    d.name AS driver_name
FROM 
    drivers d
LEFT JOIN 
    trips t ON d.driver_id = t.driver_id AND t.status = 'completed'
WHERE 
    t.trip_id IS NULL;

--Output: Sakti Man ( that was added in later part of lecture) is the only driver registered in the system
-- who has zero completed trips.

-------------- Query 3 ------------------

--Average fare per pickup city, descending.  (3-table JOIN · AVG)
SELECT 
    l.city_name,
    ROUND(AVG(t.fare_amount), 2) AS avg_fare
FROM 
    trips t
INNER JOIN 
    locations l ON t.pickup_location_id = l.location_id
INNER JOIN 
    drivers d ON t.driver_id = d.driver_id
GROUP BY 
    l.city_name
ORDER BY 
    avg_fare DESC; 

--Output:Hetauda and Butwal have higher fare compared to the other cities like Kathmandu, 
-- suggesting shorter distances results in lower fare. 


-------------- Query 4 ------------------
--Rides where pickup and dropoff city are the same. (Same-table join)

SELECT 
    t.trip_id,
    t.status,
    t.fare_amount,
    p_loc.city_name AS shared_city
FROM 
    trips t
INNER JOIN 
    locations p_loc ON t.pickup_location_id = p_loc.location_id
INNER JOIN 
    locations d_loc ON t.dropoff_location_id = d_loc.location_id
WHERE 
    p_loc.city_name = d_loc.city_name;

--Output: The database contains a high volume of intra-city records with different statuses.


--Re-write Week 1 Q7 (total revenue) on the new schema. (Schema migration · verify)
SELECT 
    SUM(t.fare_amount) AS total_fare
FROM 
    trips t
WHERE 
    t.status = 'completed';

--Output: The total revenue shifted slightly from Week 1 probably due to the update in our database.

