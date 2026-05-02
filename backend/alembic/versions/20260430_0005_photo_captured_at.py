"""add photo captured timestamp

Revision ID: 20260430_0005
Revises: 20260430_0004
Create Date: 2026-04-30
"""

from alembic import op
import sqlalchemy as sa

from app.core.config import get_settings


revision = "20260430_0005"
down_revision = "20260430_0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    schema = get_settings().database_schema
    op.add_column(
        "plant_photos",
        sa.Column("captured_at", sa.DateTime(timezone=True), nullable=True),
        schema=schema,
    )


def downgrade() -> None:
    schema = get_settings().database_schema
    op.drop_column("plant_photos", "captured_at", schema=schema)
