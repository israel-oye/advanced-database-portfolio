import enum
import uuid
from datetime import date, datetime, timezone
from decimal import Decimal

from kowojo_db.base import Base
from sqlalchemy import Boolean, Date, DateTime
from sqlalchemy import Enum as SAEnum
from sqlalchemy import ForeignKey, Numeric, String, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship


class DuesFrequency(str, enum.Enum):
    """
    How often this dues schedule recurs.
    ONE_TIME means it is a single payment with no recurrence.
    """
    ONE_TIME = "one_time"
    WEEKLY = "weekly"
    MONTHLY = "monthly"
    QUARTERLY = "quarterly"
    BIANNUAL = "biannual"
    ANNUAL = "annual"


class DuesSchedule(Base):
    """
    Defines a dues payment rule set by an organisation.

    An organisation can have multiple dues schedules running
    at the same time — for example:
        - "2026 Annual Dues" — ₦10,000 per year
        - "Development Levy 2026" — ₦2,500 one-time

    Members pay against a specific dues schedule, which is why
    Transactions reference both the member and the dues schedule.

    Note: Numeric is used for the amount (instead of Float) because
    Numeric is exact — it stores the precise decimal value.
    Float can introduce tiny rounding errors, which is unacceptable
    for financial data.
    """
    __tablename__ = "dues_schedules"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tenants.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="The organisation that owns this dues schedule"
    )

    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="Human-readable name e.g. 'Annual Dues 2026'"
    )

    description: Mapped[str | None] = mapped_column(
        String(500),
        nullable=True,
    )

    # Numeric(10, 2) means: up to 10 digits total, 2 of which are
    # after the decimal point. Handles amounts up to 99,999,999.99
    amount: Mapped[Decimal] = mapped_column(
        Numeric(10, 2),
        nullable=False,
        comment="Amount to be paid per cycle"
    )

    currency: Mapped[str] = mapped_column(
        String(3),
        nullable=False,
        default="NGN",
        comment="ISO 4217 currency code e.g. NGN, USD"
    )

    frequency: Mapped[DuesFrequency] = mapped_column(
        SAEnum(DuesFrequency, name="dues_frequency_enum", values_callable=lambda x: [e.value for e in x]),
        nullable=False,
        comment="How often this payment is expected"
    )

    start_date: Mapped[date] = mapped_column(
        Date,
        nullable=False,
        comment="When this dues schedule becomes active"
    )

    end_date: Mapped[date | None] = mapped_column(
        Date,
        nullable=True,
        comment="When this dues schedule expires. Null means it is open-ended."
    )

    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relationships
    tenant: Mapped["Tenant"] = relationship(
        "Tenant", back_populates="dues_schedules"
    )
    transactions: Mapped[list["Transaction"]] = relationship(
        "Transaction", back_populates="dues_schedule"
    )

    def __repr__(self) -> str:
        return (
            f"<DuesSchedule id={self.id} name={self.name!r} "
            f"amount={self.amount} currency={self.currency!r}>"
        )
