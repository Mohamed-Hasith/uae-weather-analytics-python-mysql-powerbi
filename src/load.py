import logging

from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL
from sqlalchemy.exc import SQLAlchemyError

from config import MYSQL_CONFIG

logger = logging.getLogger(__name__)


def get_database_engine():
    """
    Create a connection to MySQL.
    """

    if not MYSQL_CONFIG["password"]:
        raise ValueError(
            "MySQL password is missing. "
            "Please configure MYSQL_PASSWORD."
        )

    database_url = URL.create(
        drivername="mysql+pymysql",
        username=MYSQL_CONFIG["username"],
        password=MYSQL_CONFIG["password"],
        host=MYSQL_CONFIG["host"],
        port=MYSQL_CONFIG["port"],
        database=MYSQL_CONFIG["database"]
    )

    engine = create_engine(
        database_url,
        connect_args={"connect_timeout": 10}
    )

    return engine


def load_weather_data(df):
    """
    Insert hourly forecast records or update an existing
    forecast version in the MySQL database.
    """

    upsert_query = """
    INSERT INTO hourly_forecasts (
        city,
        latitude,
        longitude,
        time,
        collected_at,
        temperature,
        humidity,
        feels_like,
        precipitation,
        wind_speed,
        wind_direction
    )
    VALUES (
        :city,
        :latitude,
        :longitude,
        :time,
        :collected_at,
        :temperature,
        :humidity,
        :feels_like,
        :precipitation,
        :wind_speed,
        :wind_direction
    ) AS new
    ON DUPLICATE KEY UPDATE
        latitude = new.latitude,
        longitude = new.longitude,
        temperature = new.temperature,
        humidity = new.humidity,
        feels_like = new.feels_like,
        precipitation = new.precipitation,
        wind_speed = new.wind_speed,
        wind_direction = new.wind_direction;
    """

    engine = None

    try:
        logger.info("Connecting to MySQL database...")

        engine = get_database_engine()

        records = df.to_dict(orient="records")

        with engine.begin() as connection:

            connection.execute(
                text(upsert_query),
                records
            )

        logger.info(
            "Hourly forecast data loaded successfully. "
            "Records processed: %s",
            len(records)
        )

    except SQLAlchemyError:
        logger.exception("MySQL database operation failed.")
        raise

    except Exception:
        logger.exception(
            "Unexpected error occurred during forecast loading."
        )
        raise

    finally:

        if engine is not None:
            engine.dispose()

            logger.info(
                "MySQL database connection resources released."
            )