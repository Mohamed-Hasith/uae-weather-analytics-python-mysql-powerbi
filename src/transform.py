import logging
import pandas as pd

from config import CITIES, TIMEZONE

logger = logging.getLogger(__name__)


def transform_weather_data(weather_data):
    """
    Transform and validate hourly Open-Meteo forecast JSON
    responses into a structured Pandas DataFrame.
    """

    weather_records = []

    # Check whether all four cities were received.
    if len(weather_data) != len(CITIES):
        raise ValueError(
            f"Expected {len(CITIES)} locations, "
            f"but received {len(weather_data)}."
        )

    # Generate one collection timestamp for this API batch.
    collected_at = (
        pd.Timestamp.now(tz=TIMEZONE)
        .floor("s")
        .tz_localize(None)
    )

    # Process each city's hourly forecast.
    for city_name, api_response in zip(CITIES, weather_data):

        if "hourly" not in api_response:
            raise ValueError(
                f"Hourly forecast data missing for {city_name}."
            )

        hourly = api_response["hourly"]

        required_columns = [
            "time",
            "temperature_2m",
            "relative_humidity_2m",
            "apparent_temperature",
            "precipitation",
            "wind_speed_10m",
            "wind_direction_10m"
        ]

        # Check whether all required variables exist.
        for column in required_columns:

            if column not in hourly:
                raise ValueError(
                    f"Missing {column} data for {city_name}."
                )

        # Ensure all hourly arrays have the same length.
        array_lengths = {
            column: len(hourly[column])
            for column in required_columns
        }

        if len(set(array_lengths.values())) != 1:
            raise ValueError(
                f"Inconsistent hourly data lengths for {city_name}: "
                f"{array_lengths}"
            )

        # Convert hourly arrays into individual records.
        for index, forecast_time in enumerate(hourly["time"]):

            record = {
                "city": city_name,
                "latitude": api_response["latitude"],
                "longitude": api_response["longitude"],
                "time": forecast_time,
                "collected_at": collected_at,
                "temperature": hourly["temperature_2m"][index],
                "humidity": hourly["relative_humidity_2m"][index],
                "feels_like": hourly["apparent_temperature"][index],
                "precipitation": hourly["precipitation"][index],
                "wind_speed": hourly["wind_speed_10m"][index],
                "wind_direction": hourly["wind_direction_10m"][index]
            }

            weather_records.append(record)

    # Create a Pandas DataFrame.
    df = pd.DataFrame(weather_records)

    logger.info("Starting hourly forecast data validation...")

    if df.empty:
        raise ValueError("No hourly forecast records available.")

    # Convert forecast timestamps into datetime format.
    df["time"] = pd.to_datetime(
        df["time"],
        errors="coerce"
    )

    if df["time"].isnull().any():
        raise ValueError("Invalid forecast timestamps detected.")

    # Determine the next complete forecast hour in UAE time.
    forecast_start = (
        pd.Timestamp.now(tz=TIMEZONE)
        .ceil("h")
        .tz_localize(None)
    )

    forecast_end = forecast_start + pd.Timedelta(hours=24)

    # Keep only the next 24 hourly forecast periods.
    df = df[
        (df["time"] >= forecast_start) &
        (df["time"] < forecast_end)
    ].copy()

    if df.empty:
        raise ValueError(
            "No forecast records found for the next 24 hours."
        )

    # Check for missing values.
    if df.isnull().any().any():
        raise ValueError("Missing values detected in forecast data.")

    # Validate that all four expected cities are present.
    if set(df["city"].unique()) != set(CITIES.keys()):
        raise ValueError(
            "Forecast data does not contain all four expected cities."
        )

    # Validate 24 forecast records per city.
    records_per_city = df.groupby("city").size()

    if not records_per_city.eq(24).all():
        raise ValueError(
            f"Expected 24 forecast records per city. "
            f"Received: {records_per_city.to_dict()}"
        )

    # Validate temperature.
    if not df["temperature"].between(-90, 65).all():
        raise ValueError("Temperature outside acceptable range.")

    # Validate feels-like temperature.
    if not df["feels_like"].between(-90, 65).all():
        raise ValueError(
            "Feels-like temperature outside acceptable range."
        )

    # Validate humidity.
    if not df["humidity"].between(0, 100).all():
        raise ValueError("Humidity must be between 0 and 100.")

    # Validate precipitation.
    if (df["precipitation"] < 0).any():
        raise ValueError("Negative precipitation detected.")

    # Validate wind speed.
    if (df["wind_speed"] < 0).any():
        raise ValueError("Negative wind speed detected.")

    # Validate wind direction.
    if not df["wind_direction"].between(0, 360).all():
        raise ValueError("Invalid wind direction detected.")

    # Check for duplicate city and forecast-time combinations.
    if df.duplicated(subset=["city", "time"]).any():
        raise ValueError(
            "Duplicate city/forecast-time records detected."
        )

    # Sort records for easier inspection.
    df = df.sort_values(
        by=["city", "time"]
    ).reset_index(drop=True)

    logger.info("Hourly forecast validation completed successfully.")
    logger.info("Forecast records validated: %s", len(df))
    logger.info("Cities included: %s", df["city"].nunique())
    logger.info("Records per city: %s", records_per_city.to_dict())
    logger.info("Columns available: %s", len(df.columns))
    logger.info("Forecast window: %s to %s", forecast_start, forecast_end)
    logger.info("Collection timestamp: %s", collected_at)

    return df