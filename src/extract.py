import logging
import time
import requests

from config import (
    API_URL,
    TIMEZONE,
    WEATHER_VARIABLES,
    CITIES,
    FORECAST_DAYS,
    REQUEST_TIMEOUT
)

logger = logging.getLogger(__name__)


def extract_weather_data():
    """
    Extract hourly weather forecast data for four UAE cities
    from the Open-Meteo API with automatic retries.
    """

    params = {
        "latitude": ",".join(
            str(city["latitude"]) for city in CITIES.values()
        ),
        "longitude": ",".join(
            str(city["longitude"]) for city in CITIES.values()
        ),
        "hourly": ",".join(WEATHER_VARIABLES),
        "forecast_days": FORECAST_DAYS,
        "timezone": TIMEZONE
    }

    max_attempts = 4

    for attempt in range(1, max_attempts + 1):

        try:
            logger.info(
                "Sending hourly weather forecast API request. "
                "Attempt %s of %s",
                attempt,
                max_attempts
            )

            response = requests.get(
                API_URL,
                params=params,
                timeout=REQUEST_TIMEOUT
            )

            response.raise_for_status()

            weather_data = response.json()

            if isinstance(weather_data, dict):
                weather_data = [weather_data]

            if len(weather_data) != len(CITIES):
                raise ValueError(
                    f"Expected {len(CITIES)} locations, "
                    f"but received {len(weather_data)}."
                )

            logger.info(
                "Hourly forecast extracted successfully. Locations: %s",
                len(weather_data)
            )

            return weather_data

        except requests.exceptions.RequestException as error:

            logger.warning(
                "API request failed on attempt %s: %s",
                attempt,
                error
            )

            if attempt == max_attempts:
                logger.exception(
                    "API extraction failed after %s attempts.",
                    max_attempts
                )
                raise

            wait_time = 2 ** attempt

            logger.info(
                "Retrying API request in %s seconds...",
                wait_time
            )

            time.sleep(wait_time)