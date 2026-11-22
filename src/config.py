import keyring
import os

# ==========================================
# 1. PROJECT CONFIGURATION
# ==========================================

PROJECT_NAME = "UAE Weather Analytics"


# ==========================================
# 2. OPEN-METEO API CONFIGURATION
# ==========================================

API_URL = "https://api.open-meteo.com/v1/forecast"

TIMEZONE = "Asia/Dubai"

WEATHER_VARIABLES = [
    "temperature_2m",
    "relative_humidity_2m",
    "apparent_temperature",
    "precipitation",
    "wind_speed_10m",
    "wind_direction_10m"
]

FORECAST_DAYS = 2


# ==========================================
# 3. UAE CITY CONFIGURATION
# ==========================================

CITIES = {
    "Ajman": {
        "latitude": 25.417284,
        "longitude": 55.526344
    },

    "Dubai": {
        "latitude": 25.219162,
        "longitude": 55.260906
    },

    "Abu Dhabi": {
        "latitude": 24.428822,
        "longitude": 54.364998
    },

    "Sharjah": {
        "latitude": 25.318258,
        "longitude": 55.393590
    }
}


# ==========================================
# 4. MYSQL DATABASE CONFIGURATION
# ==========================================

MYSQL_CONFIG = {
    "host": "127.0.0.1",
    "port": 3306,
    "database": "uae_weather_analytics",
    "username": os.getenv("MYSQL_USER", "root"),
    "password": keyring.get_password(
        "UAE_Weather_Analytics",
        "root"
    )
}


# ==========================================
# 5. PIPELINE CONFIGURATION
# ==========================================

COLLECTION_INTERVAL = 60  # Minutes

REQUEST_TIMEOUT = 30  # Seconds