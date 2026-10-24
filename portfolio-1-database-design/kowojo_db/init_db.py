"""
init_db.py
----------
Run this script once to create all Kowojọ tables in your PostgreSQL database.

Usage:
    From the portfolio-1-database-design/ directory:
        python -m kowojo_db.init_db

What it does:
    1. Reads your DATABASE_URL from the .env file
    2. Connects to PostgreSQL
    3. Creates all tables defined in the models/ package
       (if they don't already exist)

After running this successfully:
    - Open DBeaver and connect to the same database
    - Right-click the schema → "View Diagram" to generate the ERD
    - Export the diagram as a PNG for the portfolio submission
"""

# This import is critical — it registers all models with Base.metadata
# so SQLAlchemy knows which tables to create.
import kowojo_db.models  # noqa: F401
from kowojo_db.base import Base
from kowojo_db.database import engine


def create_tables() -> None:
    print("Connecting to database...")
    print(f"Engine: {engine.url}\n")

    print("Creating tables...")
    # create_all() inspects Base.metadata (the registry of all models)
    # and issues CREATE TABLE statements for any table that doesn't
    # already exist. It is safe to run multiple times.
    Base.metadata.create_all(bind=engine)

    print("\nAll tables created successfully.")
    print("\nTables in this schema:")
    for table_name in Base.metadata.tables:
        print(f"  - {table_name}")

    print(
        "\nNext step: Open DBeaver, connect to your database, "
        "and generate the ER diagram."
    )


if __name__ == "__main__":
    create_tables()
