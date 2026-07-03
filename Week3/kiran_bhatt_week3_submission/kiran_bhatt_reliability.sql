-- week3_reliability.sql
-- Week 3 Assignment
---Student: Kiran Bhatt

-- All SQL runs against the normalized schema from Week 2
-- (drivers, riders, locations, trips)

-- ─────────────────────────────────────────────────────────────────
-- Q1: Add indexes to the trips table
--
-- Before adding ANY index, run EXPLAIN ANALYZE on each query below
-- and record the execution time in a comment.
-- Then add your indexes and run EXPLAIN ANALYZE again.
-- The comparison IS the answer — not just the CREATE INDEX statement.
-- ─────────────────────────────────────────────────────────────────

-- Baseline queries — run EXPLAIN ANALYZE on each BEFORE indexing:

-- Query A: filter by driver
EXPLAIN ANALYZE
SELECT
	*
FROM
	trips
WHERE
	driver_id = 3;

-- Query B: filter by status
EXPLAIN ANALYZE
SELECT
	*
FROM
	trips
WHERE
	status = 'cancelled';


-- Query C: filter by driver AND status (common in the pipeline)EXPLAIN ANALYZE
SELECT
	*
FROM
	trips
WHERE
	driver_id = 3
	AND status = 'completed';


-- Now adding the indexes, and re-running the EXPLAIN ANALYZE for queries above


----IMPLEMENTATION OF INDEXES: 
CREATE INDEX idx_trips_driver_id ON
trips(driver_id);

CREATE INDEX idx_trips_status ON
trips(status);

CREATE INDEX idx_trips_driver_status ON
trips(driver_id, status);

--COMPARISON OF THE PERFORMANCE--

-- Query A: filter by driver
EXPLAIN ANALYZE
SELECT
	*
FROM
	trips
WHERE
	driver_id = 3;
/*
QUERY PLAN BEFORE INDEXING:                    
Seq Scan on trips  (cost=0.00..1)
  Filter: (driver_id = 3)       
  Rows Removed by Filter: 4520  
  Buffers: shared read=64       
Planning:                       
  Buffers: shared hit=89 read=4 
Planning Time: 1.844 ms         
Execution Time: 2.015 ms 

QUERY PLAN AFTER INDEXING:

QUERY PLAN                   
-----------------------------
Bitmap Heap Scan on trips  (c
  Recheck Cond: (driver_id = 
  Heap Blocks: exact=64      
  Buffers: shared hit=64 read
  ->  Bitmap Index Scan on id
        Index Cond: (driver_i
        Index Searches: 1    
        Buffers: shared read=
Planning:                    
  Buffers: shared hit=44 read
Planning Time: 0.808 ms      
Execution Time: 0.282 ms    */ 

-- Query B: filter by status
EXPLAIN ANALYZE
SELECT
	*
FROM
	trips
WHERE
	status = 'cancelled';
/* QUERY PLAN BEFORE INDEXING            
-------------------------
Seq Scan on trips  (cost=
  Filter: ((status)::text
  Rows Removed by Filter:
  Buffers: shared hit=64 
Planning Time: 0.090 ms  
Execution Time: 0.685 ms  */

/* QUERY PLAN AFTER INDEXING            
-------------------------
QUERY PLAN                
--------------------------
Bitmap Heap Scan on trips 
  Recheck Cond: ((status):
  Heap Blocks: exact=64   
  Buffers: shared hit=64 r
  ->  Bitmap Index Scan on
        Index Cond: ((stat
        Index Searches: 1 
        Buffers: shared re
Planning:                 
  Buffers: shared hit=3   
Planning Time: 0.228 ms   
Execution Time: 0.937 ms  */

-- Query C: filter by driver AND status (common in the pipeline)
EXPLAIN ANALYZE
SELECT
	*
FROM
	trips
WHERE
	driver_id = 3
	AND status = 'completed';
/* QUERY PLAN BEFORE INDEXING               
---------------------------
Seq Scan on trips  (cost=0.
  Filter: ((driver_id = 3) 
  Rows Removed by Filter: 4
  Buffers: shared hit=64   
Planning Time: 0.100 ms    
Execution Time: 0.554 ms   */


/* QUERY PLAN AFTER INDEXING               
---------------------------
QUERY PLAN              
------------------------
Bitmap Heap Scan on trip
  Recheck Cond: ((driver
  Heap Blocks: exact=63 
  Buffers: shared hit=65
  ->  Bitmap Index Scan 
        Index Cond: ((dr
        Index Searches: 
        Buffers: shared 
Planning Time: 0.184 ms 
Execution Time: 0.277 ms */

-- ─────────────────────────────────────────────────────────────────
-- Q2: Create completed_trips_view
--
-- Must return only completed trips with ALL of these columns:
--   trip_id, driver_name, rider_name,
--   pickup_city, dropoff_city,
--   fare_amount, distance_km, rating,
--   payment_method, requested_at, completed_at
--
-- No IDs in the output — use JOINs to resolve all foreign keys.
-- ─────────────────────────────────────────────────────────────────

DROP VIEW IF EXISTS completed_trips_view;
-- YOUR VIEW HERE:
CREATE VIEW completed_trips_view AS
SELECT
	t.trip_id,
	d.name AS driver_name,
	p.name AS rider_name,
	pck.city_name AS pickup_city,
	dst.city_name AS dropoff_city,
	t.fare_amount,
	t.distance_km,
	t.rating,
	pm.name AS payment_method,
	t.requested_at,
	t.completed_at
FROM
	trips t
INNER JOIN drivers d ON
	t.driver_id = d.driver_id
INNER JOIN passengers p ON
	t.passenger_id = p.passenger_id
INNER JOIN locations pck ON
	t.pickup_location_id = pck.location_id
INNER JOIN locations dst ON
	t.dropoff_location_id = dst.location_id
LEFT JOIN payment_methods pm ON
	t.payment_method_id = pm.payment_method_id
WHERE
	t.status = 'completed';

-- Verify:
SELECT
	*
FROM
	completed_trips_view
LIMIT 5;

SELECT
	COUNT(*)
FROM
	completed_trips_view;
-- Expected count: ~2862 (all completed trips)
-- Output: 2863 


-- ─────────────────────────────────────────────────────────────────
-- Q3: Create driver_summary view
--
-- Must show one row per driver with:
--   driver_name
--   total_trips          (all statuses)
--   completed_trips
--   cancelled_trips
--   cancellation_rate    (cancelled / total * 100, rounded to 1dp)
--   avg_fare             (completed trips only, rounded to 2dp)
--   avg_rating           (completed trips only, rounded to 1dp)
--
-- Challenge: use COUNT(*) FILTER (WHERE ...) instead of CASE WHEN
-- ─────────────────────────────────────────────────────────────────


-- YOUR VIEW HERE:
CREATE VIEW driver_summary AS
SELECT
	d.name AS driver_name,
	COUNT(t.trip_id) AS total_trips,
	COUNT(t.trip_id) FILTER (
	WHERE t.status = 'completed') AS completed_trips,
	COUNT(t.trip_id) FILTER (
	WHERE t.status = 'cancelled') AS cancelled_trips,
	ROUND(
        (COUNT(t.trip_id) FILTER (WHERE t.status = 'cancelled')::NUMERIC / 
         NULLIF(COUNT(t.trip_id), 0) * 100), 1
    ) AS cancellation_rate,
	ROUND(
        AVG(t.fare_amount) FILTER (WHERE t.status = 'completed')::NUMERIC, 2
    ) AS avg_fare,
	ROUND(
        AVG(t.rating) FILTER (WHERE t.status = 'completed')::NUMERIC, 1
    ) AS avg_rating
FROM
	drivers d
LEFT JOIN trips t ON
	d.driver_id = t.driver_id
GROUP BY
	d.driver_id,
	d.name;
-- Verify:
SELECT
	*
FROM
	driver_summary
ORDER BY
	completed_trips DESC;


-- ─────────────────────────────────────────────────────────────────
-- Q4: Transaction with intentional failure
--
-- Write a transaction that:
--   1. Inserts a new driver named 'Test Driver'
--   2. Inserts 3 valid trips for that driver
--   3. Inserts a 4th trip with rating = 99 (violates CHECK constraint)
--
-- The entire transaction should roll back.
-- Verify with: SELECT * FROM drivers WHERE name = 'Test Driver';
-- Expected: 0 rows (atomicity — nothing committed)
-- ─────────────────────────────────────────────────────────────────

-- YOUR TRANSACTION HERE:
BEGIN;
-- 1. Insert a new driver
INSERT
	INTO
	drivers (name)
VALUES ('Test Driver');
-- 2. Insert 3 valid trips (Fetches the fallback lookup fields correctly based on your schema structure)
INSERT
	INTO
	trips (driver_id,
	passenger_id,
	pickup_location_id,
	dropoff_location_id,
	fare_amount,
	distance_km,
	status,
	requested_at,
	completed_at,
	rating,
	payment_method_id)
VALUES 
((
SELECT
	driver_id
FROM
	drivers
WHERE
	name = 'Test Driver'
LIMIT 1),
1,
1,
2,
15.00,
5.2,
'completed',
'2026-01-01 10:00:00',
'2026-01-01 10:15:00',
4.5,
(
SELECT
	payment_method_id
FROM
	payment_methods
LIMIT 1)),
((
SELECT
	driver_id
FROM
	drivers
WHERE
	name = 'Test Driver'
LIMIT 1),
1,
1,
2,
22.50,
7.1,
'completed',
'2026-01-02 11:00:00',
'2026-01-02 11:20:00',
5.0,
(
SELECT
	payment_method_id
FROM
	payment_methods
LIMIT 1)),
((
SELECT
	driver_id
FROM
	drivers
WHERE
	name = 'Test Driver'
LIMIT 1),
1,
1,
2,
10.00,
3.0,
'completed',
'2026-01-03 12:00:00',
'2026-01-03 12:10:00',
4.0,
(
SELECT
	payment_method_id
FROM
	payment_methods
LIMIT 1));
-- 3. Insert a 4th trip with rating = 99 (triggers CHECK constraint failure)
INSERT
	INTO
	trips (driver_id,
	passenger_id,
	pickup_location_id,
	dropoff_location_id,
	fare_amount,
	distance_km,
	status,
	requested_at,
	completed_at,
	rating,
	payment_method_id)
VALUES 
((
SELECT
	driver_id
FROM
	drivers
WHERE
	name = 'Test Driver'
LIMIT 1),
1,
1,
2,
30.00,
12.5,
'completed',
'2026-01-04 13:00:00',
'2026-01-04 13:30:00',
99,
(
SELECT
	payment_method_id
FROM
	payment_methods
LIMIT 1));

ROLLBACK;


-- Verification query:
SELECT
	'drivers' AS tbl,
	COUNT(*) AS test_driver_rows
FROM
	drivers
WHERE
	name = 'Test Driver'
UNION ALL
SELECT
	'trips',
	COUNT(*)
FROM
	trips t
JOIN drivers d ON
	t.driver_id = d.driver_id
WHERE
	d.name = 'Test Driver';
-- Expected: 0 / 0
-- Output: The transaction successfully rolled back all changes after the constraint failure. driver/trips = 0/0.    
-- ─────────────────────────────────────────────────────────────────


-- Q6 (STRETCH): Window function — running total fare per driver
--
-- For each completed trip, show:
--   trip_id, driver_name, requested_at, fare_amount,
--   running_total_fare (driver's cumulative fare up to this trip)
--
-- Use: SUM(fare_amount) OVER (PARTITION BY driver_id ORDER BY requested_at)
-- Order the final output by driver_name, requested_at
-- ─────────────────────────────────────────────────────────────────

-- QUERY:  
SELECT
	t.trip_id,
	d.name AS driver_name,
	t.requested_at,
	t.fare_amount,
	SUM(t.fare_amount) OVER (
        PARTITION BY t.driver_id
ORDER BY
	t.requested_at
    ) AS running_total_fare
FROM
	trips t
JOIN drivers d ON
	t.driver_id = d.driver_id
WHERE
	t.status = 'completed'
ORDER BY
	driver_name,
	t.requested_at;
-- OVER and SUM used as the window function that will keep all individual trip rows visible instead of collapsing them.
-- PARTITION BY groups the trips by each unique driver so their earnings are calculated independently,
-- resetting the cumulative fare counter back to '0' whenever it shifts to a different driver's trip history.


