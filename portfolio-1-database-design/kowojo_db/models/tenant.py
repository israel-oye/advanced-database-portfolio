import uuid
from datetime import datetime, timezone

from kowojo_db.base import Base
from sqlalchemy import Boolean, DateTime, String, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship


class Tenant(Base):
    """
    Represents an organisation registered on the Kowojọ platform.

    A tenant is the top-level owner of all data within their scope.
    Every other record in the system (members, dues, transactions)
    belongs to a tenant. This is what makes the system multi-tenant —
    each organisation's data is separated by their tenant_id.
    """
    __tablename__ = "tenants"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        # server_default generates the UUID at the database level as a fallback.
        # gen_random_uuid() is a built-in PostgreSQL function for this.
        server_default=text("gen_random_uuid()"),
    )

    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="Full name of the organisation e.g. 'Osun State Alumni Association'"
    )

    # A slug is a URL-safe, lowercase, hyphenated version of the name.
    # e.g. "Osun State Alumni" becomes "osun-state-alumni"
    # It's used to identify the organisation in URLs and must be unique.
    slug: Mapped[str] = mapped_column(
        String(100),
        unique=True,
        nullable=False,
        index=True,
        comment="URL-safe unique identifier for the organisation"
    )

    email: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        nullable=False,
        comment="Primary contact email for the organisation"
    )

    phone: Mapped[str | None] = mapped_column(
        String(20),
        nullable=True,
    )

    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
        comment="Whether the organisation's account is currently active"
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

    members: Mapped[list["Member"]] = relationship(
        "Member", back_populates="tenant", cascade="all, delete-orphan"
    )
    designations: Mapped[list["Designation"]] = relationship(
        "Designation", back_populates="tenant", cascade="all, delete-orphan"
    )
    dues_schedules: Mapped[list["DuesSchedule"]] = relationship(
        "DuesSchedule", back_populates="tenant", cascade="all, delete-orphan"
    )
    audit_logs: Mapped[list["AuditLog"]] = relationship(
        "AuditLog", back_populates="tenant"
    )

    def __repr__(self) -> str:
        return f"<Tenant id={self.id} name={self.name!r}>"
