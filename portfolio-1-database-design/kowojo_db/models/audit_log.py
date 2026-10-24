import uuid
from datetime import datetime, timezone
from sqlalchemy import String, Text, DateTime, ForeignKey, text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import UUID

from kowojo_db.base import Base


class AuditLog(Base):
    """
    An append-only record of every significant action in the system.

    'Append-only' means rows are only ever inserted, never updated
    or deleted. This preserves a trustworthy history of what happened,
    who did it, and when — critical for a financial platform.

    Examples of actions that produce an audit log entry:
        - payment.successful   : a payment was confirmed
        - payment.reversed     : a payment was reversed
        - member.suspended     : a member's status was changed to suspended
        - member.approved      : a new member was approved by an admin
        - dues.created         : a new dues schedule was created

    The target_type + target_id combination tells you *what* was affected.
    For example: target_type="transaction", target_id="<uuid>" points to
    a specific row in the transactions table.
    """
    __tablename__ = "audit_logs"

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
        comment="The organisation this log entry belongs to"
    )

    # The user who performed the action.
    # nullable=True because some events are system-generated
    # (e.g. an automated payment expiry check), with no human actor.
    actor_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        comment="The user who triggered this event. Null for system-generated events."
    )

    # Short, dot-namespaced action identifier.
    # Keeping it machine-readable allows filtering and searching.
    action: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        index=True,
        comment="Machine-readable action name e.g. 'payment.reversed', 'member.suspended'"
    )

    # The type of record that was affected.
    target_type: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        comment="The table/entity that was affected e.g. 'transaction', 'member'"
    )

    # The ID of the specific record that was affected, stored as a string
    # since it could reference any table's primary key.
    target_id: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="The primary key of the affected record"
    )

    # A plain-English explanation of what happened.
    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Human-readable summary of the event"
    )

    # Audit logs should never be updated, only inserted.
    # There is intentionally no updated_at column.
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relationships
    tenant: Mapped["Tenant"] = relationship("Tenant", back_populates="audit_logs")
    actor: Mapped["User | None"] = relationship(
        "User",
        back_populates="audit_logs",
        foreign_keys=[actor_id],
    )

    def __repr__(self) -> str:
        return (
            f"<AuditLog id={self.id} "
            f"action={self.action!r} "
            f"target_type={self.target_type!r} "
            f"target_id={self.target_id!r}>"
        )
