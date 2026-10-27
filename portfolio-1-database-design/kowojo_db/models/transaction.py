import enum
import uuid
from datetime import datetime, timezone
from decimal import Decimal

from kowojo_db.base import Base
from sqlalchemy import DateTime
from sqlalchemy import Enum as SAEnum
from sqlalchemy import ForeignKey, Numeric, String, text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship


class TransactionStatus(str, enum.Enum):
    """
    The lifecycle states of a payment transaction.

    PENDING   — Payment initiated but not yet confirmed by the gateway
    SUCCESSFUL — Payment confirmed and recorded
    FAILED    — Payment attempt was unsuccessful
    REVERSED  — A previously successful payment was reversed/refunded
    """
    PENDING = "pending"
    SUCCESSFUL = "successful"
    FAILED = "failed"
    REVERSED = "reversed"


class Transaction(Base):
    """
    Records every payment attempt made by a member.

    This is the most critical table in the system. Every row here
    represents money moving (or attempting to move).

    Key design decisions:
    - tenant_id is stored directly here (denormalisation).
      Technically it is derivable via member → tenant, but storing
      it here makes tenant-scoped queries much faster without joins.
      In financial systems, this trade-off is standard and acceptable.

    - amount is stored on the transaction itself, not just referenced
      from the dues schedule. This is intentional: if the dues amount
      changes in the future, historical transactions must still reflect
      what was actually paid at the time.

    - metadata (JSONB) stores the raw response from the payment gateway
      (e.g. Paystack). JSONB is PostgreSQL's binary JSON type — it is
      stored efficiently and can be queried. This avoids needing a
      separate table for gateway-specific fields that may vary.
    """
    __tablename__ = "transactions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tenants.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
        comment="Denormalised tenant reference for fast scoped queries"
    )

    member_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("members.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
        comment="The member who made this payment"
    )

    dues_schedule_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("dues_schedules.id", ondelete="RESTRICT"),
        nullable=False,
        comment="Which dues schedule this payment is for"
    )

    # Amount paid at the time of the transaction.
    # Stored independently of dues_schedule.amount for historical accuracy.
    amount: Mapped[Decimal] = mapped_column(
        Numeric(10, 2),
        nullable=False,
    )

    currency: Mapped[str] = mapped_column(
        String(3),
        nullable=False,
        default="NGN",
    )

    status: Mapped[TransactionStatus] = mapped_column(
        SAEnum(
            TransactionStatus,
            name="transaction_status_enum",
            values_callable=lambda x: [e.value for e in x],
        ),
        default=TransactionStatus.PENDING,
        server_default=TransactionStatus.PENDING.value,
        nullable=False,
        index=True,
    )

    # The unique reference code returned by the payment gateway.
    # Used to match this record with the gateway's own records.
    payment_reference: Mapped[str | None] = mapped_column(
        String(255),
        unique=True,
        nullable=True,
        index=True,
        comment="Unique reference from the payment gateway (e.g. Paystack)"
    )

    payment_channel: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
        comment="How payment was made e.g. card, bank_transfer, ussd"
    )

    paid_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="Timestamp when payment was confirmed. Null until confirmed."
    )

    # Raw JSON response from the payment gateway.
    # Stored as JSONB so it can be queried if needed, but without
    # requiring a rigid schema for gateway-specific fields.
    gateway_response: Mapped[dict | None] = mapped_column(
        JSONB,
        nullable=True,
        comment="Raw response payload from the payment gateway"
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=text("NOW()"),
        nullable=False,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=text("NOW()"),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relationships
    tenant: Mapped["Tenant"] = relationship("Tenant")
    member: Mapped["Member"] = relationship(
        "Member", back_populates="transactions"
    )
    dues_schedule: Mapped["DuesSchedule"] = relationship(
        "DuesSchedule", back_populates="transactions"
    )

    def __repr__(self) -> str:
        return (
            f"<Transaction id={self.id} "
            f"amount={self.amount} "
            f"status={self.status.value!r}>"
        )
