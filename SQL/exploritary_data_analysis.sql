-- Compare successive forecast snapshots
WITH forecast_comparison AS
(
    SELECT
        city,
        time AS forecast_time,
        collected_at,

        temperature AS current_temperature,

        LAG(temperature) OVER (
            PARTITION BY city, time
            ORDER BY collected_at
        ) AS previous_temperature,

        LAG(collected_at) OVER (
            PARTITION BY city, time
            ORDER BY collected_at
        ) AS previous_collected_at

    FROM hourly_forecasts
)

SELECT
    city,
    forecast_time,
    previous_collected_at,
    collected_at,
    previous_temperature,
    current_temperature,

    ROUND(
        current_temperature - previous_temperature, 2
    ) AS temperature_revision

FROM forecast_comparison
WHERE previous_temperature IS NOT NULL
ORDER BY collected_at DESC, city, forecast_time
LIMIT 30;


-- Quantify forecast revisions across all cities
WITH forecast_comparison AS
(
    SELECT
        city,
        time,
        collected_at,
        temperature,

        LAG(temperature) OVER (
            PARTITION BY city, time
            ORDER BY collected_at
        ) AS previous_temperature

    FROM hourly_forecasts
),

revisions AS
(
    SELECT
        city,
        temperature - previous_temperature AS revision
    FROM forecast_comparison
    WHERE previous_temperature IS NOT NULL
)

SELECT
    city,
    COUNT(*) AS total_comparisons,

    SUM(revision <> 0) AS changed_forecasts,

    SUM(revision = 0) AS unchanged_forecasts,

    ROUND(AVG(ABS(revision)), 3) AS avg_absolute_revision,

    ROUND(MAX(ABS(revision)), 2) AS maximum_revision,

    ROUND(
        100.0 * SUM(revision <> 0) / COUNT(*), 2
    ) AS percentage_changed

FROM revisions
GROUP BY city
ORDER BY avg_absolute_revision DESC;


-- Does forecast lead time affect revisions?
WITH forecast_comparison AS
(
    SELECT
        city,
        time,
        collected_at,
        temperature,

        LAG(temperature) OVER (
            PARTITION BY city, time
            ORDER BY collected_at
        ) AS previous_temperature

    FROM hourly_forecasts
),

revisions AS
(
    SELECT
        city,

        TIMESTAMPDIFF(
            HOUR,
            collected_at,
            time
        ) AS forecast_lead_hours,

        ABS(temperature - previous_temperature)
            AS absolute_revision

    FROM forecast_comparison
    WHERE previous_temperature IS NOT NULL
)

SELECT
    CASE
        WHEN forecast_lead_hours BETWEEN 0 AND 6
            THEN '0-6 hours'
        WHEN forecast_lead_hours BETWEEN 7 AND 12
            THEN '7-12 hours'
        WHEN forecast_lead_hours BETWEEN 13 AND 18
            THEN '13-18 hours'
        WHEN forecast_lead_hours BETWEEN 19 AND 24
            THEN '19-24 hours'
        ELSE 'Above 24 hours'
    END AS forecast_horizon,

    COUNT(*) AS total_comparisons,

    ROUND(AVG(absolute_revision), 3)
        AS avg_absolute_revision,

    ROUND(MAX(absolute_revision), 2)
        AS maximum_revision

FROM revisions
GROUP BY forecast_horizon
ORDER BY MIN(forecast_lead_hours);



-- City-level weather comparison
WITH latest_batch AS
(
    SELECT MAX(collected_at) AS latest_collection
    FROM hourly_forecasts
)

SELECT
    h.city,

    COUNT(*) AS forecast_records,

    ROUND(AVG(h.temperature), 2) AS avg_temperature,
    ROUND(MIN(h.temperature), 2) AS min_temperature,
    ROUND(MAX(h.temperature), 2) AS max_temperature,

    ROUND(AVG(h.feels_like), 2) AS avg_feels_like,
    ROUND(AVG(h.humidity), 2) AS avg_humidity,

    ROUND(AVG(h.precipitation), 2) AS avg_precipitation,
    ROUND(AVG(h.wind_speed), 2) AS avg_wind_speed,
    ROUND(MAX(h.wind_speed), 2) AS max_wind_speed

FROM hourly_forecasts h
JOIN latest_batch lb
    ON h.collected_at = lb.latest_collection

GROUP BY h.city
ORDER BY avg_temperature DESC;



-- Temperature analysis
WITH ranked_temperatures AS
(
    SELECT
        city,
        time,
        temperature,

        ROW_NUMBER() OVER (
            PARTITION BY city
            ORDER BY temperature DESC, time
        ) AS hottest_rank,

        ROW_NUMBER() OVER (
            PARTITION BY city
            ORDER BY temperature ASC, time
        ) AS coldest_rank

    FROM hourly_forecasts
    WHERE collected_at = (
        SELECT MAX(collected_at)
        FROM hourly_forecasts
    )
)

SELECT
    city,
    MAX(CASE WHEN hottest_rank = 1 THEN time END)
        AS hottest_time,

    MAX(CASE WHEN hottest_rank = 1 THEN temperature END)
        AS highest_temperature,

    MAX(CASE WHEN coldest_rank = 1 THEN time END)
        AS coldest_time,

    MAX(CASE WHEN coldest_rank = 1 THEN temperature END)
        AS lowest_temperature

FROM ranked_temperatures
GROUP BY city;



-- Analyse hourly temperature trends
SELECT
    city,
    HOUR(time) AS forecast_hour,

    ROUND(AVG(temperature), 2) AS avg_temperature,
    ROUND(AVG(feels_like), 2) AS avg_feels_like

FROM hourly_forecasts
WHERE collected_at = (
    SELECT MAX(collected_at)
    FROM hourly_forecasts
)

GROUP BY city, HOUR(time)
ORDER BY city, forecast_hour;


-- Calculate the difference between actual temperature and feels-like temperature
SELECT
    city,

    ROUND(AVG(feels_like - temperature), 2)
        AS avg_feels_like_difference,

    ROUND(MAX(feels_like - temperature), 2)
        AS maximum_difference,

    ROUND(MIN(feels_like - temperature), 2)
        AS minimum_difference

FROM hourly_forecasts
WHERE collected_at = (
    SELECT MAX(collected_at)
    FROM hourly_forecasts
)

GROUP BY city
ORDER BY avg_feels_like_difference DESC;



-- Compare humidity across cities
SELECT
    city,

    ROUND(AVG(humidity), 2) AS avg_humidity,
    MIN(humidity) AS minimum_humidity,
    MAX(humidity) AS maximum_humidity,

    SUM(humidity >= 70) AS high_humidity_hours,

    ROUND(
        100.0 * SUM(humidity >= 70) / COUNT(*), 2
    ) AS high_humidity_percentage

FROM hourly_forecasts
WHERE collected_at = (
    SELECT MAX(collected_at)
    FROM hourly_forecasts
)

GROUP BY city
ORDER BY avg_humidity DESC;


-- Investigate the relationship between temperature and humidity
SELECT
    city,

    ROUND(AVG(temperature), 2) AS avg_temperature,
    ROUND(AVG(humidity), 2) AS avg_humidity,

    ROUND(
        AVG(temperature * humidity)
        - AVG(temperature) * AVG(humidity),
        3
    ) AS temperature_humidity_covariance

FROM hourly_forecasts
WHERE collected_at = (
    SELECT MAX(collected_at)
    FROM hourly_forecasts
)

GROUP BY city;



-- Identify cities with the highest forecast precipitation
SELECT
    city,

    ROUND(SUM(precipitation), 2) AS total_precipitation,

    ROUND(AVG(precipitation), 2) AS avg_precipitation,

    SUM(precipitation > 0) AS precipitation_hours,

    ROUND(
        100.0 * SUM(precipitation > 0) / COUNT(*), 2
    ) AS precipitation_hour_percentage,

    MAX(precipitation) AS maximum_hourly_precipitation

FROM hourly_forecasts
WHERE collected_at = (
    SELECT MAX(collected_at)
    FROM hourly_forecasts
)

GROUP BY city
ORDER BY total_precipitation DESC;



-- Identify hours with predicted precipitation
SELECT
    city,
    time,
    precipitation,
    temperature,
    humidity,
    wind_speed

FROM hourly_forecasts
WHERE precipitation > 0
AND collected_at = (
    SELECT MAX(collected_at)
    FROM hourly_forecasts
)

ORDER BY precipitation DESC;


-- Compare wind speed across cities
SELECT
    city,

    ROUND(AVG(wind_speed), 2) AS avg_wind_speed,

    ROUND(MIN(wind_speed), 2) AS min_wind_speed,

    ROUND(MAX(wind_speed), 2) AS max_wind_speed,

    SUM(wind_speed >= 20) AS strong_wind_hours

FROM hourly_forecasts
WHERE collected_at = (
    SELECT MAX(collected_at)
    FROM hourly_forecasts
)

GROUP BY city
ORDER BY avg_wind_speed DESC;



-- Analyse wind direction distribution
SELECT
    city,

    CASE
        WHEN wind_direction >= 337.5
          OR wind_direction < 22.5 THEN 'North'

        WHEN wind_direction < 67.5 THEN 'North-East'
        WHEN wind_direction < 112.5 THEN 'East'
        WHEN wind_direction < 157.5 THEN 'South-East'
        WHEN wind_direction < 202.5 THEN 'South'
        WHEN wind_direction < 247.5 THEN 'South-West'
        WHEN wind_direction < 292.5 THEN 'West'
        ELSE 'North-West'
    END AS wind_direction_category,

    COUNT(*) AS forecast_hours

FROM hourly_forecasts
WHERE collected_at = (
    SELECT MAX(collected_at)
    FROM hourly_forecasts
)

GROUP BY city, wind_direction_category
ORDER BY city, forecast_hours DESC;


-- Humidity revisions
WITH humidity_comparison AS
(
    SELECT
        city,
        time,
        collected_at,
        humidity,

        LAG(humidity) OVER (
            PARTITION BY city, time
            ORDER BY collected_at
        ) AS previous_humidity

    FROM hourly_forecasts
)

SELECT
    city,

    COUNT(*) AS total_comparisons,

    SUM(humidity <> previous_humidity)
        AS changed_forecasts,

    ROUND(
        AVG(ABS(humidity - previous_humidity)), 2
    ) AS avg_absolute_revision,

    MAX(ABS(humidity - previous_humidity))
        AS maximum_revision

FROM humidity_comparison
WHERE previous_humidity IS NOT NULL

GROUP BY city
ORDER BY avg_absolute_revision DESC;


-- Precipitation revisions
WITH precipitation_comparison AS
(
    SELECT
        city,
        time,
        collected_at,
        precipitation,

        LAG(precipitation) OVER (
            PARTITION BY city, time
            ORDER BY collected_at
        ) AS previous_precipitation

    FROM hourly_forecasts
)

SELECT
    city,

    COUNT(*) AS total_comparisons,

    SUM(precipitation <> previous_precipitation)
        AS changed_forecasts,

    ROUND(
        AVG(ABS(precipitation - previous_precipitation)), 3
    ) AS avg_absolute_revision,

    MAX(ABS(precipitation - previous_precipitation))
        AS maximum_revision

FROM precipitation_comparison
WHERE previous_precipitation IS NOT NULL

GROUP BY city
ORDER BY avg_absolute_revision DESC;


-- Feels-like temperature revisions
WITH feels_like_comparison AS
(
    SELECT
        city,
        time,
        collected_at,
        feels_like,

        LAG(feels_like) OVER (
            PARTITION BY city, time
            ORDER BY collected_at
        ) AS previous_feels_like

    FROM hourly_forecasts
)

SELECT
    city,

    COUNT(*) AS total_comparisons,

    SUM(feels_like <> previous_feels_like)
        AS changed_forecasts,

    ROUND(
        AVG(ABS(feels_like - previous_feels_like)), 3
    ) AS avg_absolute_revision,

    MAX(ABS(feels_like - previous_feels_like))
        AS maximum_revision

FROM feels_like_comparison
WHERE previous_feels_like IS NOT NULL

GROUP BY city
ORDER BY avg_absolute_revision DESC;


-- Wind direction revisions
WITH direction_comparison AS
(
    SELECT
        city,
        time,
        collected_at,
        wind_direction,

        LAG(wind_direction) OVER (
            PARTITION BY city, time
            ORDER BY collected_at
        ) AS previous_direction

    FROM hourly_forecasts
),

direction_revisions AS
(
    SELECT
        city,

        LEAST(
            ABS(wind_direction - previous_direction),
            360 - ABS(wind_direction - previous_direction)
        ) AS direction_revision

    FROM direction_comparison
    WHERE previous_direction IS NOT NULL
)

SELECT
    city,

    COUNT(*) AS total_comparisons,

    SUM(direction_revision <> 0)
        AS changed_forecasts,

    ROUND(AVG(direction_revision), 2)
        AS avg_direction_revision,

    MAX(direction_revision)
        AS maximum_direction_revision

FROM direction_revisions
GROUP BY city
ORDER BY avg_direction_revision DESC;



-- Check collection frequency and batch completeness
SELECT
    collected_at,

    COUNT(*) AS total_records,

    COUNT(DISTINCT city) AS total_cities,

    COUNT(DISTINCT time) AS distinct_forecast_hours,

    MIN(time) AS forecast_start,

    MAX(time) AS forecast_end

FROM hourly_forecasts

GROUP BY collected_at
ORDER BY collected_at DESC;


-- Compare forecast coverage between batches
WITH batch_summary AS
(
    SELECT
        collected_at,
        COUNT(*) AS total_records,
        COUNT(DISTINCT city) AS total_cities,
        MIN(time) AS forecast_start,
        MAX(time) AS forecast_end

    FROM hourly_forecasts
    GROUP BY collected_at
)

SELECT
    *,

    LAG(total_records) OVER (
        ORDER BY collected_at
    ) AS previous_batch_records,

    total_records - LAG(total_records) OVER (
        ORDER BY collected_at
    ) AS record_difference

FROM batch_summary
ORDER BY collected_at DESC;


-- Identify the number of forecast snapshots available for each forecast hour
SELECT
    city,
    time AS forecast_time,

    COUNT(DISTINCT collected_at) AS snapshot_count,

    MIN(collected_at) AS first_collection,

    MAX(collected_at) AS latest_collection

FROM hourly_forecasts

GROUP BY city, time

ORDER BY city, time;


-- Compare revision magnitudes across variables
WITH weather_comparison AS
(
    SELECT
        city,
        time,
        collected_at,

        temperature,
        LAG(temperature) OVER (
            PARTITION BY city, time
            ORDER BY collected_at
        ) AS previous_temperature,

        humidity,
        LAG(humidity) OVER (
            PARTITION BY city, time
            ORDER BY collected_at
        ) AS previous_humidity,

        feels_like,
        LAG(feels_like) OVER (
            PARTITION BY city, time
            ORDER BY collected_at
        ) AS previous_feels_like,

        precipitation,
        LAG(precipitation) OVER (
            PARTITION BY city, time
            ORDER BY collected_at
        ) AS previous_precipitation,

        wind_speed,
        LAG(wind_speed) OVER (
            PARTITION BY city, time
            ORDER BY collected_at
        ) AS previous_wind_speed

    FROM hourly_forecasts
)

SELECT
    city,

    ROUND(AVG(ABS(temperature - previous_temperature)), 3)
        AS temperature_revision,

    ROUND(AVG(ABS(humidity - previous_humidity)), 3)
        AS humidity_revision,

    ROUND(AVG(ABS(feels_like - previous_feels_like)), 3)
        AS feels_like_revision,

    ROUND(AVG(ABS(precipitation - previous_precipitation)), 3)
        AS precipitation_revision,

    ROUND(AVG(ABS(wind_speed - previous_wind_speed)), 3)
        AS wind_speed_revision

FROM weather_comparison

WHERE previous_temperature IS NOT NULL

GROUP BY city
ORDER BY temperature_revision DESC;