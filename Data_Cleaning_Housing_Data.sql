-- Data cleaning in SQL (PostgreSQL)
-- Nashville Housing Data

SELECT * 
FROM nashville_housing_data

-- CONVERT saledate to date format

-- Add a new column to store the converted dates
ALTER TABLE nashville_housing_data
ADD COLUMN SaleDateConverted DATE;

-- Update the SaleDateConverted column with the converted dates
UPDATE nashville_housing_data
SET SaleDateConverted = TO_DATE(SaleDate, 'Month DD, YYYY');

-- Populate Property Address Data
SELECT Propertyaddress
FROM nashville_housing_data
WHERE Propertyaddress is null

-- See what other data there is for records where property address is null
SELECT *
FROM nashville_housing_data
WHERE Propertyaddress is null

SELECT *
FROM nashville_housing_data
WHERE Propertyaddress is null
ORDER BY parcelid

-- based on this, we see the same parcel id exists multiple times
-- and sometimes it includes the property address.
-- so, populate the null value from a record where parcelid is shared
-- and property address is already present
-- a self-join will be required here

SELECT 
	a.parcelid, 
	a.propertyaddress, 
	b.parcelid, 
	b.propertyaddress,
	-- coalesce function will return first value which is not null
	COALESCE(a.propertyaddress, b.propertyaddress) AS propertyaddress_updated
FROM nashville_housing_data a
	JOIN nashville_housing_data b
	on a.parcelid = b.parcelid
	and a.uniqueid <> b.uniqueid
where a.propertyaddress is null

-- now, enter this column using an update statement
-- Step 1: Add a new column to the table
ALTER TABLE nashville_housing_data
ADD COLUMN propertyaddress_updated VARCHAR;

-- Step 2: update the new column with the updated property address
UPDATE nashville_housing_data AS a
SET propertyaddress_updated = COALESCE(a.propertyaddress, b.propertyaddress)
FROM nashville_housing_data AS b
WHERE a.parcelid = b.parcelid
  AND a.uniqueid <> b.uniqueid
  AND a.propertyaddress IS NULL;
  
-- Step 3: Update the null values in propertyaddress_updated with values from propertyaddress
UPDATE nashville_housing_data
SET propertyaddress_updated = propertyaddress
WHERE propertyaddress_updated IS NULL;

-- confirm that the changes are correct
SELECT parcelid, propertyaddress, propertyaddress_updated
FROM nashville_housing_data
WHERE Propertyaddress is null

SELECT 
	a.parcelid, 
	a.propertyaddress, 
	b.parcelid, 
	b.propertyaddress,
	b.propertyaddress_updated
FROM nashville_housing_data a
	JOIN nashville_housing_data b
	on a.parcelid = b.parcelid
ORDER BY a.parcelid

-- above confirms that the propertyaddress_updated column is updated
-- with address from the same parcelid

-- Breaking out the address into columns
-- Address | City | State


SELECT 
    SUBSTRING(Propertyaddress_updated FROM 1 FOR POSITION(',' IN Propertyaddress_updated) - 1) as Address,
    SUBSTRING(Propertyaddress_updated FROM POSITION(',' IN Propertyaddress_updated) + 1) as City
FROM 
    nashville_housing_data;
	
ALTER TABLE nashville_housing_data
Add column PropertySplitAddress VARCHAR,
Add column PropertySplitCity VARCHAR

UPDATE nashville_housing_data
SET PropertySplitAddress = SUBSTRING(Propertyaddress_updated FROM 1 FOR POSITION(',' IN Propertyaddress_updated) - 1)

UPDATE nashville_housing_data
SET PropertySplitCity = SUBSTRING(Propertyaddress_updated FROM POSITION(',' IN Propertyaddress_updated) + 1)

-- confirm changes
select 
* 
from 
nashville_housing_data

-- Split owneraddress into address, city and state

SELECT COALESCE(NULLIF(SPLIT_PART(owneraddress, ',', 1), ''), NULL) AS address,
       COALESCE(NULLIF(SPLIT_PART(owneraddress, ',', 2), ''), NULL) AS city,
       COALESCE(NULLIF(SPLIT_PART(owneraddress, ',', 3), ''), NULL) AS state
FROM nashville_housing_data	

ALTER TABLE nashville_housing_data
Add column OwnerSplitAddress VARCHAR,
Add column OwnerSplitCity VARCHAR,
Add column OwnerSplitState VARCHAR

UPDATE 
	nashville_housing_data
SET 
  OwnerSplitAddress = 
  	COALESCE(NULLIF(SPLIT_PART(owneraddress, ',', 1), ''), NULL),
  OwnerSplitCity = 
  	COALESCE(NULLIF(SPLIT_PART(owneraddress, ',', 2), ''), NULL),
  OwnerSplitState = 
  	COALESCE(NULLIF(SPLIT_PART(owneraddress, ',', 3), ''), NULL);

-- see what the different options are in "sold as vacant"

select soldasvacant
from nashville_housing_data
group by soldasvacant

-- based on this, 4 options. Yes, No, Y and N.

-- I want to change this to boolean yes and y = 1, no and n = 0

SELECT 
    CASE 
        WHEN soldasvacant IN ('Yes', 'Y') THEN 1
        WHEN soldasvacant IN ('No', 'N') THEN 0
        ELSE NULL -- Handle other cases if needed
    END AS soldasvacant_boolean
FROM 
    nashville_housing_data
	
Alter table nashville_housing_data
add column soldasvacant_boolean BOOL

UPDATE nashville_housing_data
SET soldasvacant_boolean = CASE 
        WHEN soldasvacant IN ('Yes', 'Y') THEN TRUE
        WHEN soldasvacant IN ('No', 'N') THEN FALSE
        ELSE NULL -- Handle other cases if needed
    END;
	
select soldasvacant, soldasvacant_boolean
from nashville_housing_data

-- Remove duplicate rows. 
-- Need a way to identify the rows using row_number()
-- partition it on attributes that should be unique to each row

WITH unique_check AS ( 
    SELECT *, 
    ROW_NUMBER() OVER (
					PARTITION BY parcelid, 
								propertyaddress, 
								saleprice, 
								legalreference 
					ORDER BY uniqueid) AS rownum
FROM 
    nashville_housing_data
ORDER BY 
    parcelid)
	
Select *
from unique_check
where rownum > 1

-- above found 119 duplicates
-- now need to delete those duplicate rows

WITH unique_check AS ( 
    SELECT *, 
    ROW_NUMBER() OVER (
					PARTITION BY parcelid, 
								propertyaddress, 
								saleprice, 
								legalreference 
					ORDER BY uniqueid) AS rownum
FROM 
    nashville_housing_data
ORDER BY 
    parcelid)

-- use a subquery to find rows where the rownum in unique_check > 1
-- then delete that subset from nashville_housing_data table

DELETE FROM nashville_housing_data
WHERE (parcelid, propertyaddress, saleprice, legalreference, uniqueid) IN (
    SELECT parcelid, propertyaddress, saleprice, legalreference, uniqueid
    FROM unique_check
    WHERE rownum > 1
);

-- Delete unused columns

ALTER TABLE nashville_housing_data
DROP COLUMN owneraddress,
DROP COLUMN taxdistrict,
DROP COLUMN propertyaddress,
DROP COLUMN propertyaddress_updated,
DROP COLUMN saledate;

select *
From nashville_housing_data


-- change saleprice from VARCHAR to integer

-- Update saleprice column, remove non-numeric characters, and 
-- convert to INTEGER

UPDATE nashville_housing_data
SET saleprice = 
	CAST(REGEXP_REPLACE(saleprice, '[^\d]', '', 'g') AS INTEGER);

select *
from Nashville_housing_data


