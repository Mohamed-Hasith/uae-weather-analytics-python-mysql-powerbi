import logging
from pathlib import Path


def setup_logging():
    """
    Configure logging for the UAE Weather Analytics project.
    """

    # Find the main project directory
    project_directory = Path(__file__).resolve().parent.parent

    # Create logs directory if it doesn't exist
    log_directory = project_directory / "logs"
    log_directory.mkdir(exist_ok=True)

    # Log file location
    log_file = log_directory / "pipeline.log"

    # Configure logging
    logging.basicConfig(
        level=logging.INFO,

        format="%(asctime)s | %(levelname)s | %(message)s",

        datefmt="%Y-%m-%d %H:%M:%S",

        handlers=[
            logging.FileHandler(
                log_file,
                encoding="utf-8"
            ),
            logging.StreamHandler()
        ],

        force=True
    )

    return logging.getLogger()