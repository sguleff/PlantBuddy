from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from app.core.config import get_settings


revision = "20260430_0004"
down_revision = "20260430_0003"
branch_labels = None
depends_on = None


schema = get_settings().database_schema


def upgrade():
    op.create_table(
        "plant_deep_analysis",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("plant_id", sa.String(length=36), nullable=False),
        sa.Column("status", sa.String(length=24), nullable=False),
        sa.Column("selected_photos", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("review", sa.Text(), nullable=True),
        sa.Column("trajectory", sa.Text(), nullable=True),
        sa.Column("recommendations", sa.Text(), nullable=True),
        sa.Column("care_plan", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("special_tasks", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("raw_response", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("applied", sa.Boolean(), nullable=False),
        sa.Column("last_error", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["plant_id"], [f"{schema}.plants.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        schema=schema,
    )
    op.create_index(
        op.f("ix_plant_deep_analysis_plant_id"),
        "plant_deep_analysis",
        ["plant_id"],
        unique=False,
        schema=schema,
    )
    op.create_index(
        op.f("ix_plant_deep_analysis_status"),
        "plant_deep_analysis",
        ["status"],
        unique=False,
        schema=schema,
    )


def downgrade():
    op.drop_index(op.f("ix_plant_deep_analysis_status"), table_name="plant_deep_analysis", schema=schema)
    op.drop_index(op.f("ix_plant_deep_analysis_plant_id"), table_name="plant_deep_analysis", schema=schema)
    op.drop_table("plant_deep_analysis", schema=schema)
