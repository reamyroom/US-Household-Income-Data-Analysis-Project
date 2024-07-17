USE FinalProject;

-- Preview
SELECT * 
FROM US_Household_Income;

-- Task 1: Summarizing Data by State
SELECT 
	State_Name, 
    State_ab, 
    AVG(ALand) AS Avg_Land_Area,
    AVG(AWater) AS Avg_Water_Area
FROM US_Household_Income
GROUP BY State_Name, State_ab
ORDER BY Avg_Land_Area DESC;

-- Task 2: Filtering Cities by Population Range
SELECT 
	State_Name,
	City,
    County,
    ALand
FROM US_Household_Income
WHERE ALand between 50000000 and 100000000
ORDER BY City;

-- Task 3: Counting Cities per State
SELECT 
	State_Name, 
    State_ab, 
	COUNT(City) AS cities_per_State
FROM US_Household_Income
GROUP BY State_Name, State_ab
ORDER BY cities_per_State DESC;

-- Task 4: Identifying Counties with Significant Water Area
SELECT 
	County,
	State_Name,
    SUM(AWater) AS total_water_area
FROM US_Household_Income
GROUP BY County, State_Name
ORDER BY total_water_area DESC
LIMIT 10;

-- Task 5: Finding Cities Near Specific Coordinates
SELECT 
	City,
	State_Name,
    County,
    Lat,
    Lon
FROM US_Household_Income
WHERE Lat BETWEEN 30 AND 35 and Lon BETWEEN -90 AND -85
ORDER BY Lat, Lon;

-- Task 6: Using Window Functions for Ranking
SELECT
    City,
    State_Name,
    ALand AS Land_Area,
    RANK() OVER (PARTITION BY State_Name ORDER BY ALand DESC) AS City_Rank
FROM US_Household_Income
ORDER BY State_Name, City_Rank;

-- Task 7: Creating Aggregate Reports
SELECT
    State_Name,
    State_ab,
    COUNT(City) AS cities_per_State,
    SUM(ALand) AS Total_Land_Area,
    SUM(AWater) AS Total_Water_Area
FROM US_Household_Income
GROUP BY State_Name, State_ab
ORDER BY Total_Land_Area DESC;

-- Task 8: Subqueries for Detailed Analysis
SELECT
    City,
    State_Name,
    ALand
FROM US_Household_Income
WHERE ALand > (SELECT AVG(ALand) FROM US_Household_Income)
ORDER BY ALand DESC;

-- Task 9: Identifying Cities with High Water to Land Ratios
SELECT
    City,
    State_Name,
    ALand,
    AWater,
    AWater / ALand AS Water_Land_Ratio
FROM US_Household_Income
WHERE AWater > 0.5 * ALand
ORDER BY Water_Land_Ratio DESC;

-- Task 10: Dynamic SQL for Custom Reports: 
 # Create stored procedure to generate detailed report for a given state abbreviation
DELIMITER // 

CREATE PROCEDURE us_StateReport (IN StateAb VARCHAR(2))
BEGIN
  -- Declare variables for report data
  DECLARE TotalCities INT;
  DECLARE AvgLandArea BIGINT;
  DECLARE AvgWaterArea BIGINT;

  -- Calculate total number of cities and average land & water area (output 1)
  SELECT 
    COUNT(City) AS TotalCities,
    AVG(ALand) AS AvgLandArea,
    AVG(AWater) AS AvgWaterArea
  FROM US_Household_Income
  WHERE State_ab = StateAb;

  -- Select detailed city information (output 2)
  SELECT City, ALand, AWater
  FROM US_Household_Income
  WHERE State_ab = StateAb;
END;

//

DELIMITER ;
-- Use Procedure
CALL us_StateReport('CA');
 # two output result tables retrieved

-- Task 11: Creating and Using Temporary Tables
-- Create a temporary table to store top 20 cities by land area
CREATE TEMPORARY TABLE Top20CitiesByLand (
  City VARCHAR(22) NOT NULL,
  State_Name VARCHAR(20) NOT NULL,
  ALand BIGINT NOT NULL,
  PRIMARY KEY (City,State_Name)
);

-- Insert top 20 cities with largest land area into the temp table
INSERT INTO Top20CitiesByLand (City, State_Name, ALand)
SELECT City, State_Name, ALand
FROM US_Household_Income
ORDER BY ALand DESC
LIMIT 20;

-- Calculate avg water area for the top 20 cities
SELECT 
  t.City, 
  t.State_Name, 
  t.ALand, 
  AVG(u.AWater) AS AvgWaterArea
FROM Top20CitiesByLand t
INNER JOIN US_Household_Income u ON t.City = u.City AND t.State_Name = u.State_Name
GROUP BY t.City, t.State_Name, t.ALand;

-- Drop the temporary table (optional)
DROP TEMPORARY TABLE Top20CitiesByLand;

-- Task 12: Complex Multi-Level Subqueries
 # States where State-Wise average land areas > Overall average
SELECT State_Name, AVG(ALand) AS avg_Land_Area
FROM US_Household_Income
GROUP BY State_Name -- Average Land Area for each state (State-Wise)
HAVING AVG(ALand) > (
    SELECT AVG(ALand) -- Overall Average Land Area
    FROM US_Household_Income
);

-- Task 13: Optimizing Indexes for Query Performance
 # Complex Query Scenario : Find all cities in California (CA) with a population density (population/ALand) > the avg population density for all cities in California.
WITH CalcPopulationDensity AS (
  SELECT c.State_Name, c.City, c.ALand,
         (SELECT SUM(population) FROM US_Other_Table uot
          WHERE uot.State_Name = c.State_Name AND uot.City = c.City) AS Population,
         c.ALand / (SELECT SUM(population) FROM US_Other_Table uot2
                  WHERE uot2.State_Name = 'CA') AS PopulationDensity
  FROM US_Household_Income c
  WHERE c.State_Name = 'CA'  -- Leverage State_Name index here
  AND c.City IN (  -- Leverage City index here
    SELECT DISTINCT City
    FROM US_Household_Income
    WHERE County = 'Autauga County'  -- Leverage County index here
  )
)
SELECT State_Name, City, Population, PopulationDensity
FROM CalcPopulationDensity
HAVING PopulationDensity > (
  SELECT AVG(PopulationDensity)
  FROM CalcPopulationDensity
  WHERE State_Name = 'CA'
);

SELECT 
    DISTINCT State_Name
FROM 
    US_Household_Income;
 # Before indexing: Use Explain to analyze Query Plans
EXPLAIN SELECT 
    State_Name,
    City,
    County
FROM 
    US_Household_Income
WHERE 
    State_Name = 'Alabama';
 
 # Create indexes
CREATE INDEX idx_State_Name ON US_Household_Income(State_Name);
CREATE INDEX idx_City ON US_Household_Income(City);
CREATE INDEX idx_County ON US_Household_Income(County);

 # After indexing:
EXPLAIN SELECT 
    State_Name,
    City,
    County
FROM 
    US_Household_Income
WHERE 
    State_Name = 'Alabama';

-- Task 14: Recursive Common Table Expressions (CTEs)
WITH OrderedCities AS (
    SELECT 
        City,
        State_Name,
        ALand,
        ROW_NUMBER() OVER (PARTITION BY State_Name ORDER BY City) AS rn
    FROM 
        US_Household_Income
),
CumulativeLandArea AS (
    SELECT
        `City`,
        `State_Name`,
        `ALand`,
        `ALand` AS Cumulative_Land_Area,
        `rn`
    FROM OrderedCities
    WHERE rn = 1
),
RecursiveCTE AS (
    SELECT 
        `City`,
        `State_Name`,
        `ALand`,
        `Cumulative_Land_Area`,
        `rn`
    FROM 
        CumulativeLandArea
    UNION ALL
    SELECT 
        c.`City`,
        c.`State_Name`,
        c.`ALand`,
        r.`Cumulative_Land_Area` + c.`ALand`,
        c.`rn`
    FROM 
        CumulativeLandArea c
    JOIN 
        RecursiveCTE r ON c.`State_Name` = r.`State_Name` 
                        AND c.`rn` = r.`rn` + 1
)
SELECT *
FROM `CumulativeLandArea`;

-- Task 15: Data Anomalies Detection

WITH StateAvgLandArea AS (
    SELECT 
        State_Name,
        AVG(ALand) AS Avg_Land_Area,
        STDDEV(ALand) AS StdDev_Land_Area
    FROM 
        US_Household_Income
    GROUP BY 
        State_Name
),
Anomalies AS (
    SELECT 
        u.City,
        u.State_Name,
        u.ALand,
        s.Avg_Land_Area,
        ROUND((u.ALand - s.Avg_Land_Area) / s.StdDev_Land_Area, 2) AS Anomaly_Score
    FROM 
        US_Household_Income u
    JOIN 
        StateAvgLandArea s ON u.State_Name = s.State_Name
    WHERE 
        ABS((u.ALand - s.Avg_Land_Area) / s.StdDev_Land_Area) > 2 -- Z-score threshold
)
SELECT 
    City,
    State_Name,
    ALand,
    Avg_Land_Area,
    Anomaly_Score
FROM 
    Anomalies
ORDER BY 
    Anomaly_Score DESC;
    
-- Task 16: Stored Procedures for Complex Calculations

DELIMITER $$

CREATE PROCEDURE PredictLandWaterArea(IN cityName VARCHAR(22), IN stateAbbr VARCHAR(2))
BEGIN
    DECLARE future_land_area BIGINT;
    DECLARE future_water_area BIGINT;

    -- Example calculation using a simple linear projection (replace with actual logic)
    SELECT 
        AVG(ALand) * 1.05, -- Example growth rate
        AVG(AWater) * 1.05 -- Example growth rate
    INTO 
        future_land_area,
        future_water_area
    FROM 
        US_Household_Income
    WHERE 
        City = cityName AND State_ab = stateAbbr;

    SELECT 
        cityName AS City,
        stateAbbr AS State,
        future_land_area AS Predicted_Land_Area,
        future_water_area AS Predicted_Water_Area;
END $$

DELIMITER ;

-- Task 17: Implementing Triggers for Data Integrity

-- Create the summary table
CREATE TABLE StateSummary (
    State_Name VARCHAR(20) PRIMARY KEY,
    Total_Land_Area BIGINT,
    Total_Water_Area BIGINT
);

-- Create the trigger
DELIMITER $$

CREATE TRIGGER UpdateStateSummary AFTER INSERT OR UPDATE OR DELETE ON US_Household_Income
FOR EACH ROW
BEGIN
    IF (NEW.State_Name IS NOT NULL) THEN
        REPLACE INTO StateSummary (State_Name, Total_Land_Area, Total_Water_Area)
        SELECT 
            State_Name,
            SUM(ALand),
            SUM(AWater)
        FROM 
            US_Household_Income
        GROUP BY 
            State_Name;
    END IF;
END $$

DELIMITER ;

-- Task 18: Advanced Data Encryption and Security

-- Encrypt columns
ALTER TABLE US_Household_Income
MODIFY Zip_Code VARBINARY(255),
MODIFY Area_Code VARBINARY(255);

UPDATE US_Household_Income
SET Zip_Code = AES_ENCRYPT(Zip_Code, 'encryption_key'),
    Area_Code = AES_ENCRYPT(Area_Code, 'encryption_key');

-- Decrypt data for authorized users
SELECT 
    City,
    State_Name,
    County,
    CAST(AES_DECRYPT(Zip_Code, 'encryption_key') AS CHAR) AS Decrypted_Zip_Code,
    CAST(AES_DECRYPT(Area_Code, 'encryption_key') AS CHAR) AS Decrypted_Area_Code
FROM 
    US_Household_Income;

-- Task 19: Geospatial Analysis

DELIMITER $$
DROP FUNCTION IF EXISTS haversine$$

CREATE FUNCTION haversine(
        lat1 FLOAT, lon1 FLOAT,
        lat2 FLOAT, lon2 FLOAT
     ) RETURNS FLOAT
    NO SQL DETERMINISTIC
    COMMENT 'Returns the distance in kilometers on the Earth between two known points of latitude and longitude'
BEGIN
    RETURN 6371 * ACOS(
              COS(RADIANS(lat1)) * COS(RADIANS(lat2)) *
              COS(RADIANS(lon2) - RADIANS(lon1)) +
              SIN(RADIANS(lat1)) * SIN(RADIANS(lat2))
            );
END$$

DELIMITER ;


SELECT
    City,
    State_Name,
    County,
    Lat,
    Lon,
    haversine(Lat, Lon, 34.0522, -118.2437) AS Distance_From_LA
FROM `US_Household_Income`;

-- Task 20: Analyzing Correlations

SELECT `State_Name`
       , (numbers * total_mul_area - total_land_area * total_water_area) 
         / SQRT(numbers * total_mul_land_area - total_land_area * total_land_area)
         / SQRT(numbers * total_mul_water_area - total_water_area * total_water_area) AS corr
FROM (SELECT `State_Name`
             , COUNT(*) numbers
             , SUM(CAST(ALand AS DOUBLE) * CAST(AWater AS DOUBLE)) total_mul_area
             , SUM(CAST(ALand AS DOUBLE) * CAST(ALand AS DOUBLE)) total_mul_land_area
             , SUM(CAST(AWater AS DOUBLE) * CAST(AWater AS DOUBLE)) total_mul_water_area
             , SUM(ALand) total_land_area
             , SUM(AWater) total_water_area
      FROM us_household_income
      GROUP BY `State_Name`) _cals;

-- Task 21: Hotspot Detection

WITH Stats AS (
    SELECT 
        AVG(ALand) AS Avg_Land_Area,
        STDDEV(ALand) AS StdDev_Land_Area,
        AVG(AWater) AS Avg_Water_Area,
        STDDEV(AWater) AS StdDev_Water_Area
    FROM 
        US_Household_Income
),
Hotspots AS (
    SELECT 
        City,
        State_Name,
        ALand,
        AWater,
        (ABS(ALand - (SELECT Avg_Land_Area FROM Stats)) / (SELECT StdDev_Land_Area FROM Stats)) AS Land_Area_Z_Score,
        (ABS(AWater - (SELECT Avg_Water_Area FROM Stats)) / (SELECT StdDev_Water_Area FROM Stats)) AS Water_Area_Z_Score
    FROM 
        US_Household_Income
)
SELECT 
    City,
    State_Name,
    ALand,
    AWater,
    ROUND((Land_Area_Z_Score + Water_Area_Z_Score), 2) AS Deviation_Score
FROM 
    Hotspots
ORDER BY 
    Deviation_Score DESC;
    
-- Task 22: Resource Allocation Optimization
WITH ResourceAllocation AS (
    SELECT 
        City,
        State_Name,
        ALand,
        AWater,
        (ALand + AWater) / SUM(ALand + AWater) OVER () AS Resource_Allocation_Ratio
    FROM 
        US_Household_Income
)
SELECT 
    City,
    State_Name,
    ALand,
    AWater,
    Resource_Allocation_Ratio AS Allocated_Resources
FROM 
    ResourceAllocation
ORDER BY 
    Allocated_Resources DESC;
    
/*
Task 0: Summarizing Data by State (Special)

Question:

Assume that you will have new data each week. Can you please create store procedure and create event to active procedure every weeks to update and clean new data (From Cleaning Tasks)?
Hint: TimeStamp
*/
-- Adjusted code with error handling and logging

-- Create the Scheduled Event
DELIMITER $$

CREATE PROCEDURE CleanAndUpdateData()
BEGIN
    -- Remove duplicates
    DELETE t1 FROM US_Household_Income t1
    INNER JOIN US_Household_Income t2 
    WHERE 
        t1.row_id < t2.row_id AND 
        t1.id = t2.id AND 
        t1.State_Code = t2.State_Code AND 
        t1.State_Name = t2.State_Name AND 
        t1.State_ab = t2.State_ab AND 
        t1.County = t2.County AND 
        t1.City = t2.City AND 
        t1.Place = t2.Place AND 
        t1.Type = t2.Type AND 
        t1.Primary_ = t2.Primary_ AND 
        t1.Zip_Code = t2.Zip_Code AND 
        t1.Area_Code = t2.Area_Code AND 
        t1.ALand = t2.ALand AND 
        t1.AWater = t2.AWater AND 
        t1.Lat = t2.Lat AND 
        t1.Lon = t2.Lon;

    -- Update Type field
    UPDATE US_Household_Income
    SET `Type` = 'CDP'
    WHERE `Type` = 'CPD';

    UPDATE US_Household_Income
    SET `Type` = 'Borough'
    WHERE `Type` = 'Boroughs';

    -- Add additional cleaning tasks as required
END $$

DELIMITER ;

--  End task
DELIMITER $$

CREATE EVENT CleanAndUpdateDataEvent
ON SCHEDULE EVERY 1 WEEK
STARTS CURRENT_TIMESTAMP
DO
BEGIN
    CALL CleanAndUpdateData();
END $$

DELIMITER ;

SET GLOBAL event_scheduler = ON;
SHOW VARIABLES LIKE 'event_scheduler';
SHOW EVENTS;