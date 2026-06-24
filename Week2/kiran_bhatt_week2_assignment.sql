------------------------------------------------------------------
-- Week 2 Assignment: Database Normalization Migration
-- Student: Kiran Bhatt
------------------------------------------------------------------

-- ------------------------------------------------------------
--STEP 1: DROP EXISTING TABLES AND CRETAE LOOKUP TABLES
----------------------------------------------------------------
-- Drop existing tables

DROP TABLE IF EXISTS trips;
DROP TABLE IF EXISTS drivers;
DROP TABLE IF EXISTS passengers;
DROP TABLE IF EXISTS locations; 
DROP TABLE IF EXISTS payment_methods;

--Now we will create the lookup tables for the data normalization

CREATE TABLE locations(
	location_id serial PRIMARY KEY, 
	city_name varchar(100) NOT NULL UNIQUE --Unique here ensures that the values are not repeated
);


CREATE TABLE drivers(
	driver_id serial PRIMARY KEY,
	name varchar(100) NOT NULL 
);--- We do not write unique here, since we can have multiple people with the same name

CREATE TABLE passengers(
	passenger_id serial PRIMARY KEY,
	name varchar(100) NOT NULL
);  

CREATE TABLE payment_methods(
	payment_method_id serial PRIMARY KEY,
	name varchar(30) NOT NULL UNIQUE 
);
------------------------------------------------------------------
-- STEP 2: CREATE MAIN TRIPS TABLE 
------------------------------------------------------------------
CREATE TABLE trips (
    trip_id              SERIAL        PRIMARY KEY,
    driver_id            INTEGER       NOT NULL REFERENCES drivers(driver_id),
    passenger_id         INTEGER       NOT NULL REFERENCES passengers(passenger_id),
    pickup_location_id   INTEGER       NOT NULL REFERENCES locations(location_id),
    dropoff_location_id  INTEGER       NOT NULL REFERENCES locations(location_id),
    fare_amount          NUMERIC(10,2) NOT NULL CHECK (fare_amount > 0),
    distance_km          NUMERIC(6,2)  NOT NULL,
    status               VARCHAR(50)   NOT NULL CHECK (status IN ('completed','cancelled','no_show')),
    requested_at         TIMESTAMP     NOT NULL,
    completed_at         TIMESTAMP,
    rating               NUMERIC(2,1)  CHECK (rating BETWEEN 1.0 AND 5.0),
    payment_method_id    INTEGER       REFERENCES payment_methods(payment_method_id)
);

SELECT
	*
FROM
	trips; --Checking our final trips table
----------------------------------------------------------------
-- STEP 3: FIXING MESSY DATA AND STRING CLEANING 
----------------------------------------------------------------

SELECT
	DISTINCT driver_name
FROM
	rides;

SELECT
	DISTINCT trim(driver_name) --Temporarily trims the extra space 
FROM
	rides;


SELECT trim (' Sita  Tamang '); --An example of how it works


---In order to look for hidden double spaces in the driver names in our database
SELECT
	DISTINCT driver_name
FROM
	rides
WHERE
	driver_name LIKE '%  %'; 
--Output: It lists the names of drivers having double-spaces. From our database, "Sita Tamang" has the extra-double space. 

---To replace the double space between the names with a single space, we will be using Replace function

SELECT
	DISTINCT REPLACE(driver_name, '  ', ' ')
	FROM rides;

 --Output: Temporarily removes double spaces between driver names. 

SELECT
	DISTINCT lower(REPLACE(driver_name, '  ', ' '))
FROM
	rides;

SELECT
	DISTINCT lower(replace(driver_name, '  ',' '))
FROM
	rides r; 

--Output: Combines lowercasing and double-space removal in a single line.
--PostgreSQL treats lowercase function names case-insensitively and gives the exact same output.

--CAPITALIZATION AND SPACE REMOVAL 

SELECT
	DISTINCT INITCAP(REPLACE(driver_name, '  ', ' '))
FROM
	rides;
--Output: Capitalizes the first letter of each word and fixes double spaces.

--Example--

SELECT initcap('Anita j \n Rai');

--Output: Capitalizes the words into "Anita J \N Rai" but treats the \n as literal string text instead of a line break.

-- REGEXP_REPLACE TO FLATTEN NEWLINES AND SPACES
SELECT REGEXP_REPLACE(E' BISHAL j \n  Rijal', '\s+', ' ', 'g');

-- Output:  I used 'E prefix' to force PostgreSQL to read \n as a real newline, allowing regex to flatten it. 
--Otherwise it was treating the \n as literal string.

--USING ALL THE FUNCTIONS TOGETHER:

SELECT DISTINCT INITCAP(TRIM(REGEXP_REPLACE(r.driver_name, '\s+', ' ', 'g'))) FROM rides r;
--Output: The capitalization, inner space and outside padding, were all removed all at once.

-- COMPARING PICKUP AND DROPOFF CITIES: Inspect if there are overlapping names.
SELECT DISTINCT pickup_city FROM rides;
SELECT DISTINCT dropoff_city FROM rides;


-- COMBINING CITIES WITHOUT USING JOIN
SELECT DISTINCT pickup_city location FROM rides
UNION
SELECT DISTINCT dropoff_city FROM rides;


-- ISOLATING CITIES ONLY IN PICKUP
SELECT DISTINCT pickup_city FROM rides r 
EXCEPT
SELECT DISTINCT dropoff_city FROM rides;


-- FINDING CITIES COMMON TO BOTH COLUMNS
SELECT DISTINCT pickup_city FROM rides r 
INTERSECT
SELECT DISTINCT dropoff_city FROM rides;


-- COMBINING CITIES WITH DUPLICATES INCLUDED
SELECT DISTINCT pickup_city FROM rides r 
UNION ALL
SELECT DISTINCT dropoff_city FROM rides;


------------------------------------------------------------------
-- STEP 4: DATA MIGRATION — INSERTING DATA IN OUR LOOKUP TABLES
------------------------------------------------------------------
-- INSERTING CLEANED DRIVER NAMES

INSERT
	INTO
	drivers (name)
SELECT
	DISTINCT INITCAP(TRIM(REGEXP_REPLACE(r.driver_name, '\s+', ' ', 'g')))
FROM
	rides r;

--Output: Permanently migrates and inserts cleaned driver names into the drivers table.

-- INSERTING CLEANED PASSENGER NAMES
INSERT
	INTO
	passengers (name)
SELECT
	DISTINCT INITCAP(TRIM(REGEXP_REPLACE(r.passenger_name, '\s+', ' ', 'g')))
FROM
	rides r;
-- Output: Permanently migrates and inserts cleaned passenger names into the passengers table.

-- INSERTING PICKUP AND DROPOFF CITIES
INSERT
	INTO
	locations (city_name)
SELECT
	DISTINCT pickup_city
FROM
	rides
UNION 
SELECT
	DISTINCT dropoff_city
FROM
	rides;
-- Output: Combines and migrates unique pickup and dropoff locations into a single city table.

-- INSERTING VALID PAYMENT METHODS
INSERT
	INTO
	payment_methods (name)
SELECT
	DISTINCT payment_method
FROM
	rides r
WHERE
	payment_method IS NOT NULL;
-- Output: Inserts valid payment options from the raw data into the payment table while skipping missing values.

-------------------------------------------------------
-- STEP 5: COMPARING DRIVER NAMES AND RIDE ID RECORDS: 
-------------------------------------------------------

SELECT driver_id FROM drivers;
SELECT * FROM rides;

--Output: Displays the driver IDs and data in table side-by-side.

SELECT 
	(
	SELECT
		driver_id
	FROM
		drivers d
	WHERE
		d.name = INITCAP(TRIM(REGEXP_REPLACE(r.driver_name, '\s+', ' ', 'g')))) driver_id,
	*
FROM
	rides r;
--Output: Shows the driver ID number that acts as our foreign key to link these tables.

--PROOF CHECKING THAT OUR TABLES HAVE THE DATA
SELECT * FROM drivers;
SELECT * FROM passengers p;
SELECT * FROM locations;
SELECT * FROM payment_methods pm;



SELECT
	(
	SELECT
		location_id
	FROM
		locations p
	WHERE
		p.city_name = r.pickup_city) pickup_location_id,
	*
FROM
	rides r;

---Output: Shows the location ID number that acts as our foreign key to link these tables.

----------------------------------------------------------------
--  STEP 6: DATA MIGRATION IN THE TRIPS TABLE USING FOREIGN IDS
----------------------------------------------------------------
-- MIGRATING DATA INTO OUR FINAL SCHEMA USING FOREIGN KEY ID LOOKUPS

INSERT
	INTO
	trips (
    driver_id,
	passenger_id,
	pickup_location_id,
	dropoff_location_id,
	fare_amount,
	distance_km,
	status,
	requested_at,
	completed_at,
	rating,
	payment_method_id
)
SELECT
	(
	SELECT
		driver_id
	FROM
		drivers d
	WHERE
		d.name = INITCAP(TRIM(REGEXP_REPLACE(r.driver_name, '\s+', ' ', 'g')))) driver_id,
	(
	SELECT
		passenger_id
	FROM
		passengers p
	WHERE
		p.name = INITCAP(TRIM(REGEXP_REPLACE(r.passenger_name, '\s+', ' ', 'g')))) passenger_id,
	(
	SELECT
		location_id
	FROM
		locations l
	WHERE
		l.city_name = r.pickup_city) pickup_location_id,
	(
	SELECT
		location_id
	FROM
		locations l
	WHERE
		l.city_name = r.dropoff_city) dropoff_location_id,
	fare_amount,
	r.ride_distance,
	ride_status,
	requested_at,
	completed_at,
	rating,
	(
	SELECT
		payment_method_id
	FROM
		payment_methods pm
	WHERE
		pm.name = r.payment_method) payment_method_id
FROM
	rides r;


SELECT
	*
FROM
	trips; 

-- Output: The data migration is completed along with foreign keys, and normalization of the data. 


