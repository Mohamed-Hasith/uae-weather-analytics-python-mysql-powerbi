from extract import extract_weather_data
from transform import transform_weather_data
from load import load_weather_data
from logging_config import setup_logging


def run_pipeline():
    """
    Execute the complete UAE Weather Analytics ETL pipeline.
    """

    logger = setup_logging()

    logger.info("=" * 50)
    logger.info("UAE WEATHER ANALYTICS - ETL PIPELINE STARTED")
    logger.info("=" * 50)

    try:
        # STEP 1: Extract
        logger.info("STEP 1: Extracting weather data...")

        weather_data = extract_weather_data()

        # STEP 2: Transform
        logger.info("STEP 2: Transforming weather data...")

        df = transform_weather_data(weather_data)

        logger.info(
            "Transformation completed. Records: %s, Columns: %s",
            len(df),
            len(df.columns)
        )

        # STEP 3: Load
        logger.info("STEP 3: Loading data into MySQL...")

        load_weather_data(df)

        logger.info("=" * 50)
        logger.info("ETL PIPELINE COMPLETED SUCCESSFULLY!")
        logger.info("=" * 50)

    except Exception:
        logger.exception("ETL PIPELINE FAILED!")
        raise


if __name__ == "__main__":
    run_pipeline()