from alembic import op
import sqlalchemy as sa

from app.core.config import get_settings


revision = "20260430_0002"
down_revision = "20260429_0001"
branch_labels = None
depends_on = None


schema = get_settings().database_schema


def upgrade():
    op.add_column("care_plans", sa.Column("watering_amount", sa.Text(), nullable=True), schema=schema)
    op.add_column("care_plans", sa.Column("watering_check", sa.Text(), nullable=True), schema=schema)
    op.add_column("care_plans", sa.Column("fertilizer_type", sa.Text(), nullable=True), schema=schema)
    op.add_column("care_plans", sa.Column("fertilizer_amount", sa.Text(), nullable=True), schema=schema)
    op.add_column("care_plans", sa.Column("repotting_assessment", sa.Text(), nullable=True), schema=schema)
    op.add_column("care_plans", sa.Column("pruning", sa.Text(), nullable=True), schema=schema)
    op.add_column("care_plans", sa.Column("watch_outs", sa.Text(), nullable=True), schema=schema)


def downgrade():
    op.drop_column("care_plans", "watch_outs", schema=schema)
    op.drop_column("care_plans", "pruning", schema=schema)
    op.drop_column("care_plans", "repotting_assessment", schema=schema)
    op.drop_column("care_plans", "fertilizer_amount", schema=schema)
    op.drop_column("care_plans", "fertilizer_type", schema=schema)
    op.drop_column("care_plans", "watering_check", schema=schema)
    op.drop_column("care_plans", "watering_amount", schema=schema)
