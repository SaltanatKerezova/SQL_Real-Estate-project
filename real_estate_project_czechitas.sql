Tableau _for_project
KEBOOLA_WORKSPACE_73261732
Jf9y2GFLqrr6khDfSyqsaKCpeiUNsHf8

select count(*)
from "dataset-items" -- Initial table
where "createdAt" >= '2019-01-01'-- 3.6 ml rows (total 4.8 ml)
;-- 3 559 696

-- Convert all NULL values to '0' 

UPDATE "dataset-items" set "data_priceTotal" = IFNULL(try_to_decimal("data_priceTotal"),0) -- 4 817 733 updated rows


-- Creating a table with necessary fields

CREATE OR REPLACE TABLE main_table AS
WITH CorrectedData AS (
    SELECT
        "id" AS "Id",
        "createdAt"::DATE AS "Date", -- date of posting (we are interested since 2019)
        "data_title" AS "Title",
        "data_description" AS "Description", -- description from the landlord / seller
        "data_arrangement" AS "Arrangement",
        "data_offerType" AS "offerType", -- rent/sale
        "data_type" AS "propertyType", -- property type - house/flat
        TRY_TO_DECIMAL("data_priceTotal") AS "Price", -- price
        "data_priceCurrency" AS "Currency", -- currency
        TRY_TO_DECIMAL("data_livingArea") AS "livingArea",
        SPLIT_PART(SPLIT_PART("data_url", '/', 3), '.', 2) AS "Source",
        "googleGeometry_location_coordinates_0" AS "Longitude",
        "googleGeometry_location_coordinates_1" AS "Latitude",
        "data_address" AS "Address",
        "data_city" AS "City",
        COALESCE(NULLIF(TRIM("data_district"), ''), "data_city") AS "District"
        
    FROM
        "dataset-items"
    WHERE "createdAt" >= '2019-01-01'
        AND (
            ("data_offerType" = 'rent' AND TRY_TO_DECIMAL("data_priceTotal") >= 4000)
            OR ("data_offerType" = 'sale' AND TRY_TO_DECIMAL("data_priceTotal") >= 2000000)
        )
        AND "data_offerType" != 'auction'
        AND "data_type" NOT IN ('commercial', 'land', 'other') -- 'other' - like garages
        AND ("data_description" NOT ILIKE '%Pronájem pokoj%' -- exclude room rentals
            AND "data_description" NOT ILIKE '%Pronájem, Pokoj%'
            AND "data_description" NOT ILIKE '%Pronájem,Pokoj%'
            AND "data_description" NOT ILIKE '%Pronájem - Pokoj%'  
            AND "data_description" NOT ILIKE '%pokoj%')
)
SELECT *,   
    CASE
        WHEN "District" IN ('Praha', 'Hlavní město Praha') OR "Address" ILIKE '%praha%' OR "Address" ILIKE '%hlavní%' THEN 'Hlavní město Praha'
        WHEN "District" IN ('Benešov', 'Beroun', 'Kladno', 'Kolín', 'Kutná Hora', 'Mělník', 'Mladá Boleslav', 'Nymburk', 'Praha-východ', 'Praha-západ', 'Příbram', 'Rakovník') OR "Address" ILIKE '%Středoč%' OR "Address" ILIKE '%Kladno%' THEN 'Středočeský kraj'
        WHEN "District" IN ('České Budějovice', 'Český Krumlov', 'Tábor', 'Písek', 'Strakonice', 'Prachatice', 'Jindřichův Hradec') OR "Address" ILIKE '%Jihočeský%' THEN 'Jihočeský kraj'
        WHEN "District" IN ('Plzeň', 'Plzeň-město', 'Plzeň-jih', 'Plzeň-sever', 'Klatovy', 'Domažlice', 'Tachov', 'Rokycany') OR "Address" ILIKE '%Plzeň%' THEN 'Plzeňský kraj'
        WHEN "District" IN ('Karlovy Vary', 'Cheb', 'Sokolov') OR "Address" ILIKE '%Karlovarský%' THEN 'Karlovarský kraj'
        WHEN "District" IN ('Ústí nad Labem', 'Chomutov', 'Teplice', 'Děčín', 'Litoměřice', 'Louny', 'Most') OR "Address" ILIKE '%Ústecký%' OR "Address" ILIKE '%Teplice%' THEN 'Ústecký kraj'
        WHEN "District" IN ('Liberec', 'Jablonec nad Nisou', 'Česká Lípa', 'Semily') OR "Address" ILIKE '%Liberecký%' THEN 'Liberecký kraj'
        WHEN "District" IN ('Hradec Králové', 'Rychnov nad Kněžnou', 'Náchod', 'Jičín', 'Trutnov') OR "Address" ILIKE '%Královéhradecký%' THEN 'Královéhradecký kraj'
        WHEN "District" IN ('Pardubice', 'Chrudim', 'Svitavy', 'Ústí nad Orlicí') OR "Address" ILIKE '%Pardubic%' THEN 'Pardubický kraj'
        WHEN "District" IN ('Jihlava', 'Havlíčkův Brod', 'Pelhřimov', 'Třebíč', 'Žďár nad Sázavou') OR "Address" ILIKE '%Vysočina%' THEN 'Kraj Vysočina'
        WHEN "District" IN ('Brno', 'Brno-město', 'Brno-venkov', 'Znojmo', 'Vyškov', 'Blansko', 'Břeclav', 'Hodonín') OR "Address" ILIKE '%Jihomoravský%' OR "Address" ILIKE '%Brno%' OR "Address" ILIKE '%Břeclav%' THEN 'Jihomoravský kraj'
        WHEN "District" IN ('Olomouc', 'Prostějov', 'Přerov', 'Šumperk', 'Jeseník') OR "Address" ILIKE '%Olomoucký%' THEN 'Olomoucký kraj'
        WHEN "District" IN ('Zlín', 'Uherské Hradiště', 'Kroměříž', 'Vsetín') OR "Address" ILIKE '%Zlínský%' THEN 'Zlínský kraj'
        WHEN "District" IN ('Ostrava', 'Ostrava-město', 'Opava', 'Karviná', 'Frýdek-Místek', 'Nový Jičín', 'Bruntál') OR "Address" ILIKE '%Moravskoslezský%' THEN 'Moravskoslezský kraj'
        ELSE 'Not recognized'
    END AS "Region"
FROM
    CorrectedData
WHERE
    "District" != '' AND "City" != '' AND "Region" != 'Not recognized'
;

select count(*)
from main_table
; -- 851 803

select *
from main_table
;


-- Duplicates

select * from (
    select 
      (coalesce("propertyType", '') || '-' || coalesce("offerType", '') || '-' || coalesce("livingArea"::varchar, '') || '-' || coalesce("Price"::varchar, '') || '-' || YEAR("Date") || '-' || coalesce("City", '') || '-' || coalesce("District", '') || '-' || coalesce("Region", '') || '-' || coalesce("Title", '') ) as calculated,
      row_number() over (partition by calculated order by "Date" desc) as cc,
      *
    from main_table
) sub
where cc > 1
order by calculated, "Date" desc
;

-- 851,803


DELETE FROM main_table where "Id" in (
    select "Id" from (
        select 
          (coalesce("propertyType", '') || '-' || coalesce("offerType", '') || '-' || coalesce("livingArea"::varchar, '') || '-' || coalesce("Price"::varchar, '') || '-' || YEAR("Date") || '-' || coalesce("City", '') || '-' || coalesce("District", '') || '-' || coalesce("Region", '') || '-' || coalesce("Title", '') ) as calculated,
          row_number() over (partition by calculated order by "Date" desc) as cc,
          "Id"
        from main_table
    ) sub
    where cc > 1
)
; -- 251 996 rows


-- Add a new calculation column to the table (price per meter square)

ALTER TABLE main_table
ADD "PricePerM2" INT
;

SELECT *
FROM main_table
WHERE ("livingArea" IS NULL OR "livingArea" = 0)
; -- 36 099


--  Replaces all non-breaking spaces (code 160 in the ASCII table, which corresponds to &nbsp; in HTML) with normal spaces.

UPDATE main_table
SET "Title" = REPLACE("Title", CHAR(160), ' '), "Description" = REPLACE("Description", CHAR(160), ' ')
; -- 599 807 rows


-- Find from "Title" and "Description" m² or m2

UPDATE main_table
SET "livingArea" = REPLACE(REPLACE(REGEXP_SUBSTR(TRIM("Title"), '(([^+]\\d+\\s)?\\d\\d+([.,]?\\d*)?)\\s*m[²2]', 1, 1, 'ie'), ' ', ''), ',', '.')::FLOAT
WHERE ("livingArea" IS NULL OR "livingArea" = 0)
; -- 36 099 rows


UPDATE main_table
SET "livingArea" = REPLACE(REPLACE(REGEXP_SUBSTR(TRIM("Description"), '(\\d\\d+[.,]?\\d*)\\s*m[²2]', 1, 1, 'ie'), ' ', ''), ',', '.')::FLOAT
WHERE ("livingArea" IS NULL OR "livingArea" = 0)
; -- 1 107

SELECT "Title",
       "livingArea", 
       "Description",
       "propertyType",
       REPLACE(REPLACE(REGEXP_SUBSTR(TRIM("Title"), '(([^+]\\d+\\s)?\\d\\d+([.,]?\\d*)?)\\s*m[²2]', 1, 1, 'ie'), ' ', ''), ',', '.')::FLOAT AS extracted_area,
       REPLACE(REPLACE(REGEXP_SUBSTR(TRIM("Description"), '(\\d\\d+[.,]?\\d*)\\s*m[²2]', 1, 1, 'ie'), ' ', ''), ',', '.')::FLOAT AS extracted_area_d
FROM main_table
WHERE ("livingArea" IS NULL OR "livingArea" = 0) AND "propertyType" = 'apartment'
order by extracted_area
;


DELETE FROM main_table
WHERE ("livingArea" IS NULL OR "livingArea" = 0)
; -- 677 rows removed



-- Replace strange huge livingArea with lower from description > 350

SELECT "Title",
       "livingArea",
REPLACE(REPLACE(REGEXP_SUBSTR(TRIM("Description"), '(\\d\\d+[.,]?\\d*)\\s*m[²2]', 1, 1, 'ie'), ' ', ''), ',', '.')::FLOAT AS extracted_area_d,
       "Description",
       "propertyType",
       "PricePerM2"
FROM main_table
WHERE "livingArea" > 350 AND extracted_area_d < "livingArea" and "propertyType" = 'apartment'
ORDER BY "livingArea"
;

UPDATE main_table mt
SET mt."livingArea" = sub.extracted_area
FROM (
    SELECT "Id",
        REPLACE(REPLACE(REGEXP_SUBSTR(TRIM("Description"), '(\\d\\d+[.,]?\\d*)\\s*m[²2]', 1, 1, 'ie'), ' ', ''), ',', '.')::FLOAT AS extracted_area
    FROM main_table
    WHERE "livingArea" > 350 AND "propertyType" = 'apartment' AND "livingArea" > extracted_area
) AS sub
WHERE mt."Id"= sub."Id" and mt."livingArea" > sub.extracted_area
; -- 279



-- Apartment's living area is not correct (1-10)

SELECT 
        "Id",
        "Title",
       "livingArea",
       REPLACE(REPLACE(REGEXP_SUBSTR(TRIM("Description"), '(\\d+[.,]?\\d*)\\s*m[²2]', 1, 1, 'ie'), ' ', ''), ',', '.')::FLOAT AS extracted_area_first,
       REPLACE(REPLACE(REGEXP_SUBSTR(TRIM("Description"), '(\\d\\d+[.,]?\\d*)\\s*m[²2]', 1, 1, 'ie'), ' ', ''), ',', '.')::FLOAT AS extracted_area_d,
       "Description",
       "propertyType",
       "PricePerM2"
FROM main_table
WHERE "livingArea" <= 15 AND extracted_area_d > "livingArea" AND extracted_area_first != "livingArea" AND "propertyType" = 'apartment' AND "Id" <> '65d648b1d39528558e8acdd4'
ORDER BY "livingArea"
; -- 164

UPDATE main_table mt
SET mt."livingArea" = sub.extracted_area_d
FROM (
    SELECT "Id",
       REPLACE(REPLACE(REGEXP_SUBSTR(TRIM("Description"), '(\\d+[.,]?\\d*)\\s*m[²2]', 1, 1, 'ie'), ' ', ''), ',', '.')::FLOAT AS extracted_area_first,
       REPLACE(REPLACE(REGEXP_SUBSTR(TRIM("Description"), '(\\d\\d+[.,]?\\d*)\\s*m[²2]', 1, 1, 'ie'), ' ', ''), ',', '.')::FLOAT AS extracted_area_d,
    FROM main_table
    WHERE "livingArea" <= 15 AND extracted_area_d > "livingArea" AND extracted_area_first != "livingArea" AND "propertyType" = 'apartment' AND "Id" <> '65d648b1d39528558e8acdd4'
) AS sub
WHERE mt."Id"= sub."Id" and mt."livingArea" < sub.extracted_area_d
; -- 164


-- Replace strange huge livingArea with lower from description > 200

SELECT "Id","Title",
       "livingArea",
REPLACE(REPLACE(REGEXP_SUBSTR(TRIM("Description"), '(\\d\\d+[.,]?\\d*)\\s*m[²2]', 1, 1, 'ie'), ' ', ''), ',', '.')::FLOAT AS extracted_area_d,
       "Description",
       "propertyType",
       "PricePerM2"
FROM main_table
WHERE 
    "livingArea" > 200 AND 
    extracted_area_d < "livingArea" and 
    "propertyType" = 'apartment' and (
        (
            (
                "Title" like '%4+kk%' OR "Title" like '%5+kk%' OR "Title" like '%6+kk%' OR 
                "Title" like '%4+1%' OR "Title" like '%5+1%' OR "Title" like '%6+1%' OR "Title" like '%6 pokojů%' OR "Title" like '%atypick%'
            ) and extracted_area_d > 70
        ) or (
            "Title" not like '%4+kk%' AND "Title" not like '%5+kk%' AND "Title" not like '%6+kk%' AND 
            "Title" not like '%4+1%' AND "Title" not like '%5+1%' AND "Title" not like '%6+1%' AND "Title" not like '%6 pokojů%' AND "Title" not like '%atypick%'
        )
    ) AND "Id" NOT IN ('reJCWDrBJwzznEL9f', 'oKeNYymRXfbG2aoBJ', '79iBqGSZAdhXBWfXw', 'nffKrmEGkduvJManz', 'o8J9p9e3RsDYWPtbe')
ORDER BY "livingArea"
;

UPDATE main_table mt
SET mt."livingArea" = sub.extracted_area_d
FROM (
    SELECT 
        "Id","Title",
       "livingArea",
        REPLACE(REPLACE(REGEXP_SUBSTR(TRIM("Description"), '(\\d\\d+[.,]?\\d*)\\s*m[²2]', 1, 1, 'ie'), ' ', ''), ',', '.')::FLOAT AS extracted_area_d,
       "Description",
       "propertyType",
       "PricePerM2"
    FROM main_table
    WHERE 
        "livingArea" > 200 AND 
        extracted_area_d < "livingArea" and 
        "propertyType" = 'apartment' and (
            (
                (
                    "Title" like '%4+kk%' OR "Title" like '%5+kk%' OR "Title" like '%6+kk%' OR 
                    "Title" like '%4+1%' OR "Title" like '%5+1%' OR "Title" like '%6+1%' OR "Title" like '%6 pokojů%' OR "Title" like '%atypick%'
                ) and extracted_area_d > 70
            ) or (
                "Title" not like '%4+kk%' AND "Title" not like '%5+kk%' AND "Title" not like '%6+kk%' AND 
                "Title" not like '%4+1%' AND "Title" not like '%5+1%' AND "Title" not like '%6+1%' AND "Title" not like '%6 pokojů%' AND "Title" not like '%atypick%'
            )
        ) AND "Id" NOT IN ('reJCWDrBJwzznEL9f', 'oKeNYymRXfbG2aoBJ', '79iBqGSZAdhXBWfXw', 'nffKrmEGkduvJManz', 'o8J9p9e3RsDYWPtbe')
) AS sub
WHERE mt."Id"= sub."Id" -- and mt."livingArea" > sub.extracted_area
; -- 417


-- Delete extreme values

select * from main_table
where "livingArea" <9
; -- 57

DELETE FROM main_table
WHERE "livingArea" < 9
; -- 57 rows



SELECT *
FROM main_table
WHERE "livingArea" > 370 AND "propertyType" = 'apartment'
order by "livingArea"
;

DELETE FROM main_table
WHERE "livingArea" > 370 AND "propertyType" = 'apartment'
; -- 184



UPDATE main_table
SET "PricePerM2" = "Price" / "livingArea"
; -- 599 140 rows

SELECT * FROM main_table
WHERE "propertyType" = 'apartment'
ORDER BY "PricePerM2"
;


-- Remove over price

select * from main_table
where "offerType" = 'sale' AND "propertyType" = 'apartment' and "Price" > '40000000' and ("livingArea" < 120 or "Price" > '85000000')
ORDER by "Price" desc

delete from main_table
where "offerType" = 'sale' AND "propertyType" = 'apartment' and "Price" > '40000000' and ("livingArea" < 120 or "Price" > '85000000')
;


select * from main_table
where "Price" > '150000' AND "offerType" = 'rent' AND "propertyType" = 'apartment' and ("livingArea" < 120 or "Price" > '250000')
ORDER by "Price" 
;

delete from main_table
where "Price" > '150000' AND "offerType" = 'rent' AND "propertyType" = 'apartment' and ("livingArea" < 120 or "Price" > '250000')
;


select * from main_table
where "Date" = '2021-02-10' and "propertyType" = 'apartment'
;


-- Create a table with salaries from the statistics website

SELECT *
FROM "urad_data"
;

CREATE OR REPLACE TABLE salary_table AS

SELECT REPLACE("Kraj", '_', ' ') AS "Region",
    "sledovane_obdobi_mesicni_mzda" AS "AvrSalary", 
    SUBSTRING("rok", 5, 4) AS "Year"
FROM "urad_data"
WHERE "Kraj" IN (
    'Hlavní_město_Praha',
    'Středočeský_kraj',
    'Jihočeský_kraj',
    'Plzeňský_kraj',
    'Karlovarský_kraj',
    'Ústecký_kraj',
    'Liberecký_kraj',
    'Královéhradecký_kraj',
    'Pardubický_kraj',
    'Kraj_Vysočina',
    'Jihomoravský_kraj',
    'Olomoucký_kraj',
    'Zlínský_kraj',
    'Moravskoslezský_kraj')
--ORDER BY "Year"
;

SELECT *
FROM salary_table
;


-- Create InflationRate_Table

DROP TABLE IF EXISTS InflationRate_Table;

CREATE TABLE IF NOT EXISTS InflationRate_Table (
    "Date" DATE,
    "Year" INTEGER,
    "Month" INTEGER,
    "Inflation" FLOAT,
    "InflationIndex" FLOAT
);

INSERT INTO InflationRate_Table ("Date", "Year", "Month", "Inflation", "InflationIndex") VALUES
('2019-1-01', 2019, 1, 2.2, 1), ('2019-2-01', 2019, 2, 2.3, 1.001), ('2019-3-01', 2019, 3, 2.4, 1.002), ('2019-4-01', 2019, 4, 2.4, 1.002), ('2019-5-01', 2019, 5, 2.5, 1.0029), ('2019-6-01', 2019, 6, 2.5, 1.0029), ('2019-7-01', 2019, 7, 2.6, 1.0039), ('2019-8-01', 2019, 8, 2.6, 1.0039), ('2019-9-01', 2019, 9, 2.6, 1.0039), ('2019-10-01', 2019, 10, 2.7, 1.0049), ('2019-11-01', 2019, 11, 2.7, 1.0049), ('2019-12-01', 2019, 12, 2.8, 1.0059), ('2020-1-01', 2020, 1, 2.9, 1.029), ('2020-2-01', 2020, 2, 3.0, 1.031), ('2020-3-01', 2020, 3, 3.1, 1.033), ('2020-4-01', 2020, 4, 3.1, 1.033), ('2020-5-01', 2020, 5, 3.1, 1.034), ('2020-6-01', 2020, 6, 3.1, 1.034), ('2020-7-01', 2020, 7, 3.2, 1.036), ('2020-8-01', 2020, 8, 3.2, 1.036), ('2020-9-01', 2020, 9, 3.3, 1.037), ('2020-10-01', 2020, 10, 3.3, 1.0381), ('2020-11-01', 2020, 11, 3.2, 1.037), ('2020-12-01', 2020, 12, 3.2, 1.0381), ('2021-1-01', 2021, 1, 3.0, 1.0599), ('2021-2-01', 2021, 2, 2.9, 1.0609), ('2021-3-01', 2021, 3, 2.8, 1.0619), ('2021-4-01', 2021, 4, 2.8, 1.0619), ('2021-5-01', 2021, 5, 2.8, 1.063), ('2021-6-01', 2021, 6, 2.8, 1.063), ('2021-7-01', 2021, 7, 2.8, 1.065), ('2021-8-01', 2021, 8, 2.8, 1.065), ('2021-9-01', 2021, 9, 3.0, 1.0682), ('2021-10-01', 2021, 10, 3.2, 1.0713), ('2021-11-01', 2021, 11, 3.5, 1.0733), ('2021-12-01', 2021, 12, 3.8, 1.0775), ('2022-1-01', 2022, 1, 4.5, 1.1076), ('2022-2-01', 2022, 2, 5.2, 1.1161), ('2022-3-01', 2022, 3, 6.1, 1.1267), ('2022-4-01', 2022, 4, 7.0, 1.1363), ('2022-5-01', 2022, 5, 8.1, 1.1491), ('2022-6-01', 2022, 6, 9.4, 1.1629), ('2022-7-01', 2022, 7, 10.6, 1.1779), ('2022-8-01', 2022, 8, 11.7, 1.1897), ('2022-9-01', 2022, 9, 12.7, 1.2038), ('2022-10-01', 2022, 10, 13.5, 1.2159), ('2022-11-01', 2022, 11, 14.4, 1.2279), ('2022-12-01', 2022, 12, 15.1, 1.2402), ('2023-1-01', 2023, 1, 15.7, 1.2815), ('2023-2-01', 2023, 2, 16.2, 1.2969), ('2023-3-01', 2023, 3, 16.4, 1.3115), ('2023-4-01', 2023, 4, 16.2, 1.3204), ('2023-5-01', 2023, 5, 15.8, 1.3306), ('2023-6-01', 2023, 6, 15.1, 1.3385), ('2023-7-01', 2023, 7, 14.3, 1.3464), ('2023-8-01', 2023, 8, 13.6, 1.3515), ('2023-9-01', 2023, 9, 12.7, 1.3567), ('2023-10-01', 2023, 10, 12.1, 1.363), ('2023-11-01', 2023, 11, 11.4, 1.3679), ('2023-12-01', 2023, 12, 10.7, 1.3729), ('2024-1-01', 2024, 1, 9.4, 1.4019), ('2024-2-01', 2024, 2, 8.2, 1.4032), ('2024-3-01', 2024, 3, 7.1, 1.4046), ('2024-4-01', 2024, 4, 6.3, 1.4035);


SELECT * FROM INFLATIONRATE_TABLE ORDER BY "Date";

