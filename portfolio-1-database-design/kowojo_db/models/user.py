import enum
import uuid
from datetime import datetime, timezone

from kowojo_db.base import Base
from sqlalchemy import Boolean, DateTime
from sqlalchemy import Enum as SAEnum
from sqlalchemy import ForeignKey, String, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship


class RoleEnum(str, enum.Enum):
    PLATFORM_ADMIN = "platform_admin"
    ORG_ADMIN = "org_admin"
    MEMBER = "member"


class User(Base):
    """
    Represents a person with a login on the Kowojọ platform.

    A User is the authentication identity — the login credentials
    and basic personal info. It is intentionally kept separate from
    Member (which is the organisational/membership identity).

    This separation means:
    - The same user record handles login regardless of their role.
    - A member's org-specific data (Member table) can change or be
      extended without touching the authentication record.
    """
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )

    email: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        nullable=False,
        index=True,
        comment="Login email — must be unique across the entire platform"
    )

    password_hash: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="Bcrypt or argon2 hash of the user's password. Never store plain text."
    )

    first_name: Mapped[str] = mapped_column(String(100), nullable=False)
    last_name: Mapped[str] = mapped_column(String(100), nullable=False)

    phone: Mapped[str | None] = mapped_column(String(20), nullable=True)

    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )

    role: Mapped[RoleEnum] = mapped_column(
        SAEnum(RoleEnum, name="role_enum"),
        nullable=False,
        default=RoleEnum.MEMBER,
        comment=(
            "Platform-level access role. "
            "platform_admin: full access across all tenants. "
            "org_admin: manages one organisation's members and dues. "
            "member: can view own data and make payments."
        ),
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
    member: Mapped["Member | None"] = relationship(
        "Member", back_populates="user", uselist=False
    )

    audit_logs: Mapped[list["AuditLog"]] = relationship(
        "AuditLog", back_populates="actor", foreign_keys="AuditLog.actor_id"
    )

    def __repr__(self) -> str:
        return f"<User id={self.id} email={self.email!r} role={self.role.value!r}>"
