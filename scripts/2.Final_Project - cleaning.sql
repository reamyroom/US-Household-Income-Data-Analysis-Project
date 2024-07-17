USE FinalProject;

/* PREVIEW */
SELECT * 
FROM US_Household_Income;

/* CHECK NULL */
SELECT * 
FROM us_household_income
WHERE row_id IS NULL
	OR id IS NULL
	OR State_Code IS NULL
	OR State_Name IS NULL
	OR State_ab IS NULL
	OR County IS NULL
	OR City IS NULL
	OR Place IS NULL
	OR Type IS NULL
	OR Primary_ IS NULL
	OR Zip_Code IS NULL
	OR Area_Code IS NULL
	OR ALand IS NULL
	OR AWater IS NULL
	OR Lat IS NULL
	OR Lon IS NULL
; 
-- Result: only 1 row has NULL in column "Place" - delete this row
DELETE FROM us_household_income WHERE Place IS NULL;



/* CHECK DUPLICATES */
SELECT State_Code, Zip_Code, Area_Code, ALand, AWater, COUNT(*) AS DuplicateCount
FROM US_Household_Income
GROUP BY State_Code, Zip_Code,Area_Code, ALand, AWater
HAVING COUNT(*) > 1;

-- Identify row_id of duplicate values
SELECT uhi.*, d.DuplicateCount,
       ROW_NUMBER() OVER (PARTITION BY d.State_Code, d.Zip_Code, d.Area_Code, d.ALand, d.AWater ORDER BY uhi.row_id) AS DuplicateOrder
FROM US_Household_Income uhi
JOIN (
    SELECT State_Code, Zip_Code, Area_Code, ALand, AWater, COUNT(*) AS DuplicateCount
    FROM US_Household_Income
    GROUP BY State_Code, Zip_Code, Area_Code, ALand, AWater
    HAVING COUNT(*) > 1
) AS d
ON uhi.State_Code = d.State_Code
AND uhi.Zip_Code = d.Zip_Code
AND uhi.Area_Code = d.Area_Code
AND uhi.ALand = d.ALand
AND uhi.AWater = d.AWater
ORDER BY d.State_Code, d.Zip_Code, d.Area_Code, d.ALand, d.AWater, DuplicateOrder;

-- Remove Duplicates
DELETE FROM US_Household_Income
WHERE row_id IN (
    SELECT row_id
    FROM (SELECT row_id, State_Code, Zip_Code, Area_Code, ALand, AWater,
		  ROW_NUMBER() OVER (PARTITION BY State_Code, Zip_Code, Area_Code, ALand, AWater ORDER BY row_id) AS DuplicateOrder
		  FROM US_Household_Income
    ) AS Duplicates
    WHERE DuplicateOrder > 1
);



/* CHECK DATA CONSISTENCY */
select * from US_Household_Income
where city = 'Vinemont';

UPDATE US_Household_Income
SET Place = 'Autaugaville'
WHERE city = 'Vinemont' and Place IS NULL ;


-- For State, each State_Name only has 1 State_Code, 1 State_ab
SELECT 
	COUNT(DISTINCT State_Code),
    COUNT(DISTINCT State_Name),
    COUNT(DISTINCT State_ab) 
FROM us_household_income
;
-- Result: There are 52 State_Code corresponding to 52 State_ab but there are up to 53 State_Name. That means there is a State_Name that is wrong.
-- Determine the wrong State_Name
-- Step 1: Create a table containing unique values ​​of State_Code and State_Name.
SELECT DISTINCT State_Code, State_Name
FROM us_household_income;
-- Step 2: Find out the State_Code that is repeated twice and its corresponding State_Name.
WITH cte_count_state_name AS (

	WITH cte_distinct_state AS (
		SELECT DISTINCT State_Code, State_Name
		FROM us_household_income
		)
	SELECT 
		State_Code, 
		State_Name, 
		COUNT(State_Name) OVER(partition by State_Code) count_state_name
	FROM cte_distinct_state
)
SELECT 
	State_Code, 
    State_Name
FROM cte_count_state_name
WHERE count_state_name > 1
;
-- Result (2 rows): State_Code = 13 corresponds to State_Name = "Georgia" and State_Name = "georia" but "georia" is wrong
-- UPDATE: IN column State_Name, update "georia" to "Georgia"
UPDATE us_household_income
SET State_Name = CASE WHEN State_Name = 'georia' THEN 'Georgia' ELSE State_Name END;


-- For County 
-- Check special characters outside the English alphabet,puntuation,'s,and dashes. \s is a space.
SELECT DISTINCT County
FROM us_household_income
WHERE County REGEXP "[^a-z \s . ' -]"
;
-- Result (2 rows): 'Do a Ana County' and 'R o Grande Municipio' contain strange characters.
-- UPDATE: In column County, update 'Do�a Ana County' to 'Dona Ana County', update 'R�o Grande Municipio' to 'Rio Grande Municipio'
UPDATE us_household_income
SET County = CASE 
				WHEN County = 'Do�a Ana County' THEN 'Dona Ana County' 
                WHEN County = 'R�o Grande Municipio' THEN 'Rio Grande Municipio'
				ELSE County 
                END;


-- For City              
-- Check special characters outside the English alphabet,puntuation,'s,and dashes. \s is a space.
SELECT DISTINCT City
FROM us_household_income
WHERE City REGEXP "[^a-z \s . ' -]"; 
-- Result (1 rows): 'Pennsboro Wv 26415' is erroring because it contains numeric characters. The correct City name is 'Pennsboro'.
-- UPDATE: In column City, update 'Pennsboro Wv  26415' to 'Pennsboro'.
UPDATE us_household_income
SET City = CASE WHEN City = 'Pennsboro Wv  26415' THEN 'Pennsboro' ELSE City END;



-- For Place
-- Check special characters outside the English alphabet,puntuation,'s,and dashes. \s is a space.
SELECT DISTINCT Place
FROM us_household_income
WHERE Place REGEXP "[^a-z \s . ' -]"
;
UPDATE us_household_income
SET Place = CASE 
				WHEN Place = 'Raymer (New Raymer)' 	THEN 'Raymer'
				WHEN Place = 'Boquer�n' 			THEN 'Boqueron'
				WHEN Place = 'El Mang�' 			THEN 'El Mango'
				WHEN Place = 'Fr�nquez' 			THEN 'Franchise'
				WHEN Place = 'Liborio Negr�n Torres'THEN 'Liborio Negron Torres'
				WHEN Place = 'Parcelas Pe�uelas' 	THEN 'Parcelas Penuelas'
				WHEN Place = 'R�o Lajas' 			THEN 'Rio Lajas'
				ELSE Place 
                END;
                
                
-- For Type
-- View error :
SELECT DISTINCT Type
FROM us_household_income
ORDER BY 1;
-- Update error
UPDATE US_Household_Income
SET `Type` = 'CDP'
WHERE `Type` = 'CPD';

UPDATE US_Household_Income
SET `Type` = 'Borough'
WHERE `Type` = 'Boroughs';


-- Check length of Zip_Code
SELECT DISTINCT 
	State_Name,
    Zip_Code, 
    LENGTH(Zip_Code) AS length,
    CASE 
		WHEN LENGTH(Zip_Code) = 3 THEN CONCAT('00', Zip_Code)
        WHEN LENGTH(Zip_Code) = 4 THEN CONCAT('0', Zip_Code)
        ELSE Zip_Code
	END as new_Zip_Code
FROM us_household_income
ORDER BY length;
/* Result:
zip code has a 5-digit format, but data has zip codes that only have 3-4 digits. 
The zip code of the state of Puerto Rico usually has two 00s at the beginning (for example, 00601). 
Connecticut zip codes usually have a leading zero (for example, 06001).
*/

-- The Zip_Code column is in the INT data type, it is not possible to add a 0 in front of the Zip_Code to get the full 5 digits.
-- Change data type from INT to VARCHAR(5)
ALTER TABLE us_household_income 
CHANGE COLUMN `Zip_Code` `Zip_Code` VARCHAR(5) NULL DEFAULT NULL;   

-- UPDATE: In column Zip_Code, add 0 in front to make 5 digits.
UPDATE us_household_income
SET Zip_Code = CASE 
					WHEN LENGTH(Zip_Code) = 3 THEN CONCAT('00', Zip_Code)
					WHEN LENGTH(Zip_Code) = 4 THEN CONCAT('0', Zip_Code)
					ELSE Zip_Code
				END; 
  
  
  
-- For Area_Code
-- Check the format of Area_Code
SELECT DISTINCT Area_Code
FROM us_household_income
WHERE Area_Code REGEXP "[^0-9]";
-- Result (1 row): has Area_Code = 'M' which is an alphabetic character.

-- Check length of Area_Code
SELECT DISTINCT 
    Area_Code, 
    LENGTH(Area_Code) AS length
FROM us_household_income
ORDER BY length;  
-- Result: has Area_Code = 'M' with only 1 character, while other Area_Codes all have 3 digits.

-- Check information of row with Area_Code = 'M'
SELECT * 
FROM us_household_income
WHERE Area_Code = 'M';
-- Result (1 row): row_id = 28896, state of Texas, Anderson County, Pasadena city, Elkhart town

-- In places with the same location, what kind of Area_Code is there?
SELECT Area_Code, COUNT(*) as count_area_code
FROM us_household_income
WHERE 
	State_Name = 'Texas' 
	AND County = 'Anderson County' 
	AND City = 'Pasadena'
	AND Place = 'Elkhart'
GROUP BY 
	Area_Code;
-- Result (3 rows): there are 11 records containing Area_Code = 713, 1 record Area_Code = 832 and 1 record Area_Code = 'M'.

-- UPDATE: In column Area_Code, update 'M' to 713, with condition that Area_Code does not contain numeric characters within [0-9] and that the place is in the state of Texas, Anderson County, Pasadena city, Elkhart town
UPDATE us_household_income
SET Area_Code = 713
WHERE Area_Code REGEXP "[^0-9]"
	AND State_Name = 'Texas' 
	AND County = 'Anderson County' 
	AND City = 'Pasadena'
	AND Place = 'Elkhart';
    
    
-- For ALand
SELECT 
	MIN(ALand), 
	MAX(ALand), 
	AVG(ALand)
FROM us_household_income; 
-- Result (1 row): Min = 0;   MAX = 91,632,669,709  ; MEAN = 116,759,749.5149
-- Question: why can residential land area = 0???

-- Find out records with ALand = 0
SELECT * 
FROM us_household_income 
WHERE ALand = 0; 
/* Result: 70 rows 
	Rows with ALand = 0 have extremely large AWater (from 13,141,095 to 6,248,340,078)
    There may be households in the US, living on yachts, instead of living on land.
*/
