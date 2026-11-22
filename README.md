# UAE Weather Analytics

An end-to-end data analytics portfolio project that collects weather
forecast data for four UAE cities, stores repeated forecast snapshots in
MySQL, explores the data with SQL and Python, and presents current
forecasts and forecast revisions in Power BI.

## Project Overview

This project uses the Open-Meteo Forecast API to collect hourly weather
forecasts for:

-   Ajman
-   Dubai
-   Abu Dhabi
-   Sharjah

The ETL pipeline extracts forecast data, transforms and validates it,
and loads it into a local MySQL database. Repeated collection snapshots
are retained so that forecast changes over time can be examined.

## Business Questions

The analysis is designed to help answer questions such as:

1.  How do forecast temperature, humidity, feels-like temperature,
    precipitation, and wind differ across the four cities?
2.  What are the hourly temperature patterns over the forecast horizon?
3.  Which cities have the highest forecast temperatures, humidity, or
    wind?
4.  How does feels-like temperature compare with actual air temperature?
5.  How much do forecast values change between collection runs?
6.  Do forecast revisions differ by city or forecast lead time?

**Important interpretation:** a change between two forecast snapshots
measures forecast revision or stability. It does not measure forecast
accuracy. Accuracy analysis requires reliable observed weather data
matched to the forecast-valid time.

## Architecture and Data Pipeline

``` text
Open-Meteo Forecast API
          |
          v
      extract.py
          |
          v
     transform.py
          |
          v
       load.py
          |
          v
 MySQL: uae_weather_analytics
     |                 |
     v                 v
 SQL EDA         Python EDA
     |                 |
     +--------+--------+
              |
              v
          Power BI
```

The pipeline is orchestrated by `main.py`. Logging is configured in
`logging_config.py`, and execution logs are written under `logs/`.

### ETL stages

1.  **Extract** --- request hourly forecast data from Open-Meteo for
    each configured city.
2.  **Transform** --- reshape the API response into row-based records,
    select the intended forecast horizon, and validate the records.
3.  **Load** --- insert validated records into MySQL.
4.  **Log** --- record pipeline progress, errors, and completion.
5.  **Schedule** --- Windows Task Scheduler can run the pipeline
    automatically while the computer is powered on and the user is
    logged in.

A successful collection batch contains 96 records: 24 hourly forecast
records for each of four cities.

## Technology Stack

-   Python
-   Pandas and NumPy
-   Requests
-   MySQL 8
-   SQL
-   Jupyter Notebook
-   Power BI
-   Windows Task Scheduler
-   Git and GitHub

## Repository Structure

``` text
UAE_Weather_Analytics/
├── .gitignore
├── README.md
├── 01_API_Exploration.ipynb
├── logs/
│   └── pipeline.log
├── notebooks/
│   └── 01_Weather_Data_Exploration.ipynb
├── power bi/
│   ├── Weather.pbip
│   ├── Weather.Report/
│   └── Weather.SemanticModel/
├── SQL/
│   ├── data_validation.sql
│   └── exploritary_data_analysis.sql
└── src/
    ├── config.py
    ├── extract.py
    ├── transform.py
    ├── load.py
    ├── logging_config.py
    └── main.py
```

The `logs/` directory and local Power BI `.pbi` folders should be
excluded from version control. The exact contents of generated or
local-only files may differ between machines.

## Python Source Files

  -----------------------------------------------------------------------
  File                                Responsibility
  ----------------------------------- -----------------------------------
  `src/config.py`                     API settings, city coordinates,
                                      requested weather variables, and
                                      MySQL configuration

  `src/extract.py`                    Calls the Open-Meteo API and
                                      retrieves hourly forecast responses

  `src/transform.py`                  Converts API responses into
                                      structured records and performs
                                      validation

  `src/load.py`                       Creates the MySQL connection and
                                      loads transformed records

  `src/logging_config.py`             Configures application logging

  `src/main.py`                       Runs the ETL stages in sequence
  -----------------------------------------------------------------------

MySQL credentials are retrieved through Python `keyring` from Windows
Credential Manager. Do not commit passwords, tokens, `.env` files, or
other secrets.

## Data Storage

Database: `uae_weather_analytics`

The project uses two tables:

-   `hourly_forecasts` --- repeated hourly forecast snapshots collected
    from the API.
-   `weather_observations` --- a separate observations table present in
    the database.

The forecast table stores city and coordinates, forecast-valid time,
collection time, temperature, humidity, feels-like temperature,
precipitation, wind speed, and wind direction.

### Important timestamps

-   `time` is the forecast-valid time: the hour the forecast is about.
-   `collected_at` is the time the API response was collected.

Keeping both timestamps makes it possible to compare how a forecast for
the same target hour changes across successive collection runs.

A unique key on `(city, time, collected_at)` helps prevent duplicate
logical forecast records within the same collection snapshot.

## SQL Analysis

The SQL scripts are:

-   `SQL/data_validation.sql` --- checks data quality and consistency.
-   `SQL/exploritary_data_analysis.sql` --- exploratory queries and
    comparisons.

The SQL EDA examined city-level weather summaries, hourly temperature
patterns, feels-like differences, humidity, wind, precipitation, and
forecast revisions.

## Python Analysis

Notebook: `notebooks/01_Weather_Data_Exploration.ipynb`

The notebook connects to MySQL, loads the forecast and observation
tables, inspects data quality, calculates descriptive statistics, and
creates visualizations.

The forecast dataset examined in the project contained 1,728 rows across
18 collection batches, with 96 records per batch and 432 records per
city. In that inspected dataset, no missing values or duplicate forecast
records were found.

The observations table had incomplete collection-time metadata and
repeated city/time records. Its provenance and alignment with the
forecast-valid periods were not established. Therefore, it was not
treated as verified ground truth for forecast-accuracy calculations.

## Findings from the Explored Data

The following are findings from the collected sample and should not be
interpreted as permanent climate characteristics or long-term
climatological conclusions.

-   Forecast temperatures followed a similar daily pattern across the
    four cities: lower overnight, rising in the morning, generally
    peaking in the early-to-mid afternoon, then declining.
-   City-level average temperature and humidity were broadly similar in
    the inspected sample, with some differences between cities.
-   Feels-like temperature was above air temperature in the inspected
    records.
-   Wind speeds and predominant directions varied by city.
-   Precipitation was zero throughout the latest inspected 24-hour
    batch.
-   Forecast values changed between successive collection snapshots. The
    size and frequency of these revisions differed by city and forecast
    lead time.
-   In the inspected lead-time comparison, average absolute temperature
    revisions were larger for nearer forecast periods (0--12 hours) than
    for several later lead-time groups.

Forecast revisions describe how predictions changed between collection
runs; they do not show whether the forecast was correct.

## Power BI Report

Power BI project: `power bi/Weather.pbip`

The report contains two pages:

1.  **UAE · Next 24 hours** --- a current forecast monitoring view with
    city filtering, temperature and feels-like trends, humidity, wind,
    and hourly details.
2.  **Forecast revisions · 7 days** --- a view of changes between
    successive forecast snapshots over a rolling period.

The semantic model uses two imported tables:

-   `Latest Forecast` --- retrieves the rows belonging to the newest
    collection timestamp.
-   `Forecast History` --- retrieves recent forecast snapshots and uses
    a window function to compare each forecast with its previous
    collected value for the same city and target hour.

Power BI refresh is separate from the scheduled Python ETL process. The
ETL updates MySQL; the Power BI imported tables must also be refreshed
to display newly collected data.

### DAX measures

The report includes measures for forecast row count, last collection
time, mean temperature, peak temperature, mean humidity, mean feels-like
temperature, peak wind, collection count, predicted temperature, and
revision delta.

## Automation

The Windows Task Scheduler task is named `UAE Weather Analytics ETL`.

It runs the project's virtual-environment Python interpreter with
`src/main.py` as the script. The task is configured to retry failures
and to start when available.

The computer must be powered on and the user must be logged in for the
configured interactive credential access. A locked session can continue
running tasks; shutting down or logging out prevents the task from
running until the computer is available again.

## Running the Project

1.  Install Python and MySQL.
2.  Clone or download this repository.
3.  Create and activate a virtual environment.
4.  Install the Python dependencies used by the project.
5.  Configure MySQL credentials in Windows Credential Manager using the
    service and username expected by `src/config.py`.
6.  Create the `uae_weather_analytics` database and required tables.
7.  Review `src/config.py` for API, city, and database settings.
8.  Run the pipeline from the project root:

``` powershell
python src/main.py
```

Use the SQL scripts in `SQL/` for database validation and analysis. Open
the notebook in `notebooks/` to reproduce the Python exploration. Open
`power bi/Weather.pbip` in Power BI Desktop to work with the report.

The exact database setup SQL and dependency manifest should be
maintained with the project as it evolves. Do not assume credentials or
local database objects are included in this repository.

## Data and Project Limitations

-   The API provides forecast data, not historical observed weather for
    validating forecast accuracy.
-   Forecast revisions are not forecast errors.
-   The observations table inspected during this project had missing
    collection metadata and repeated city/time records; it was not
    verified as a reliable actual-weather dataset.
-   Results are based on a limited collection period and four selected
    UAE cities.
-   Power BI uses Import mode, so refreshing MySQL alone does not
    refresh the report.
-   Local credentials, virtual environments, logs, and Power BI cache
    files should not be committed.

## Possible Future Improvements

-   Add a verified source of observed weather data and align
    observations with forecast-valid timestamps.
-   Evaluate forecast accuracy using appropriate error metrics after
    data quality and timestamp alignment are established.
-   Add automated data-quality checks and pipeline monitoring.
-   Add a dependency file such as `requirements.txt`.
-   Improve documentation for database/table initialization and
    credential setup.
-   Publish or schedule Power BI dataset refresh where the deployment
    environment supports it.

## Author

UAE Weather Analytics --- a portfolio project demonstrating API data
extraction, Python ETL, MySQL data storage, SQL and Python EDA, Power BI
reporting, and Windows task automation.
