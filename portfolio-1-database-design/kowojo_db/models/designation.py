import uuid
from datetime import datetime, timezone

from kowojo_db.base import Base
from sqlalchemy import DateTime, ForeignKey, String, Text, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship


class Designation(Base):
    """
    An organisation-defined title or role label for their members.

    This is intentionally separate from the platform-level RoleEnum
    on the User model. That enum controls what a user can DO (access
    control). This table controls what a member is CALLED within
    their organisation (organisational metadata).

    Examples:
        Association A → "Admin", "Member"
        Association B → "Chairman", "Secretary", "Financial Director"

    A member's designation does not affect their permissions on the
    platform. It is display and organisational information only.
    """

    __tablename__ = "designations"

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
        comment="The organisation that owns this designation",
    )

    name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        comment="Title as defined by the organisation e.g. 'Chairman'",
    )

    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Optional explanation of what this designation means",
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    # Relationships
    tenant: Mapped["Tenant"] = relationship("Tenant", back_populates="designations")
    members: Mapped[list["Member"]] = relationship(
        "Member", back_populates="designation"
    )

    def __repr__(self) -> str:
        return f"<Designation name={self.name!r} tenant_id={self.tenant_id}>"
