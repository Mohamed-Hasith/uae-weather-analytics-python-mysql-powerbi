show tables;

describe hourly_forecasts;

SELECT *
FROM hourly_forecasts
ORDER BY collected_at DESC, city, time
LIMIT 10;

select * 
from uae_weather_analytics.hourly_forecasts;


-- First SQL analysis: Understand our dataset size
USE uae_weather_analytics;

SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT city) AS total_cities,
    COUNT(DISTINCT collected_at) AS collection_batches,
    MIN(time) AS earliest_forecast,
    MAX(time) AS latest_forecast,
    MIN(collected_at) AS first_collection,
    MAX(collected_at) AS latest_collection
FROM hourly_forecasts;

-- Second SQL analysis: Inspect collection batches
SELECT
    collected_at,
    COUNT(*) AS total_records,
    COUNT(DISTINCT city) AS cities,
    MIN(time) AS forecast_start,
    MAX(time) AS forecast_end
FROM hourly_forecasts
GROUP BY collected_at
ORDER BY collected_at DESC
LIMIT 10;


-- Validate records per city per batch
SELECT
    collected_at,
    city,
    COUNT(*) AS total_records
FROM hourly_forecasts
GROUP BY
    collected_at,
    city
ORDER BY
    collected_at DESC,
    city;
    
    
-- Check missing values (NULL)
SELECT
    COUNT(*) AS total_records,

    SUM(city IS NULL) AS missing_city,
    SUM(time IS NULL) AS missing_time,
    SUM(collected_at IS NULL) AS missing_collection_time,
    SUM(temperature IS NULL) AS missing_temperature,
    SUM(humidity IS NULL) AS missing_humidity,
    SUM(feels_like IS NULL) AS missing_feels_like,
    SUM(precipitation IS NULL) AS missing_precipitation,
    SUM(wind_speed IS NULL) AS missing_wind_speed,
    SUM(wind_direction IS NULL) AS missing_wind_direction

FROM hourly_forecasts;


-- Check invalid weather values
SELECT *
FROM hourly_forecasts
WHERE
    humidity < 0 OR humidity > 100
    OR precipitation < 0
    OR wind_speed < 0
    OR wind_direction < 0 OR wind_direction >= 360;
    
    
-- Duplicate detection using a Window Function
WITH check_duplicates AS
(
    SELECT
        id,
        city,
        time,
        collected_at,
        ROW_NUMBER() OVER (
            PARTITION BY city, time, collected_at
            ORDER BY id
        ) AS duplicate_number
    FROM hourly_forecasts
)
SELECT *
FROM check_duplicates
WHERE duplicate_number > 1;


-- invalid weather values
SELECT *
FROM hourly_forecasts
WHERE
    humidity < 0 OR humidity > 100
    OR precipitation < 0
    OR wind_speed < 0
    OR wind_direction < 0 OR wind_direction >= 360;
    
    
-- second option
SELECT
    SUM(humidity < 0 OR humidity > 100) AS invalid_humidity,
    SUM(precipitation < 0) AS invalid_precipitation,
    SUM(wind_speed < 0) AS invalid_wind_speed,
    SUM(wind_direction < 0 OR wind_direction >= 360) AS invalid_wind_direction
FROM hourly_forecasts;
