from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    """
    The shared base class for all SQLAlchemy models.
    Every model (table) in Kowojọ inherits from this class.
    SQLAlchemy uses it to keep track of all the tables that
    need to be created in the database.
    """
    pass
