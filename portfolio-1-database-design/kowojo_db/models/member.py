import enum
import uuid
from datetime import datetime, timezone

from kowojo_db.base import Base
from sqlalchemy import DateTime
from sqlalchemy import Enum as SAEnum
from sqlalchemy import ForeignKey, String, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship


class MembershipStatus(str, enum.Enum):
    """
    The possible states a membership can be in.

    Using an Enum (a fixed list of allowed values) instead of a plain
    string prevents invalid values from ever being stored in the database.
    """
    PENDING = "pending"       # Registered but not yet approved
    ACTIVE = "active"         # Fully approved and in good standing
    SUSPENDED = "suspended"   # Temporarily restricted (e.g. dues not paid)
    EXPIRED = "expired"       # Membership period has lapsed
    INACTIVE = "inactive"     # Voluntarily deactivated


class Member(Base):
    """
    Represents a person's membership within a specific organisation.

    This is the bridge between a User (who they are on the platform)
    and a Tenant (which organisation they belong to).

    A Member record holds everything about someone's membership status,
    their unique membership number within the organisation, and links
    to their payment history.

    Note: Organisation-specific profile fields (matric number, licence
    number, etc.) are NOT stored here. They live in MongoDB, linked
    to this record via the member's id.
    """
    __tablename__ = "members"

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
        comment="The organisation this membership belongs to"
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,  # One user can only have one membership (one org per user)
        comment="The user account associated with this membership"
    )

    # A human-readable membership number unique within an organisation.
    # e.g. "OSAA-00123". The application layer is responsible for
    # generating this in a meaningful format per tenant.
    membership_number: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        comment="Organisation-scoped membership identifier e.g. OSAA-00123"
    )

    status: Mapped[MembershipStatus] = mapped_column(
        SAEnum(
            MembershipStatus,
            name="membership_status_enum",
            values_callable=lambda x: [e.value for e in x],
        ),
        default=MembershipStatus.PENDING,
        server_default=MembershipStatus.PENDING.value,
        nullable=False,
    )

    joined_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=text("NOW()"),
        nullable=False,
        comment="When the member joined the organisation"
    )

    # The admin user who approved this membership.
    # nullable=True because approval may not always be required.
    approved_by: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        comment="ID of the org admin who approved this membership"
    )

    approved_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    designation_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("designations.id", ondelete="SET NULL"),
        nullable=True,
        comment="The organisation-defined title for this member e.g. Chairman",
    )

    # Relationships
    tenant: Mapped["Tenant"] = relationship("Tenant", back_populates="members")
    user: Mapped["User"] = relationship(
        "User", back_populates="member", foreign_keys=[user_id]
    )
    transactions: Mapped[list["Transaction"]] = relationship(
        "Transaction", back_populates="member", cascade="all, delete-orphan"
    )
    designation: Mapped["Designation | None"] = relationship(
        "Designation", back_populates="members"
    )

    def __repr__(self) -> str:
        return (
            f"<Member id={self.id} "
            f"membership_number={self.membership_number!r} "
            f"status={self.status.value!r}>"
        )
