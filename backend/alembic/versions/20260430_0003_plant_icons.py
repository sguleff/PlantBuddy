from alembic import op
import sqlalchemy as sa

from app.core.config import get_settings


revision = "20260430_0003"
down_revision = "20260430_0002"
branch_labels = None
depends_on = None


schema = get_settings().database_schema


def upgrade():
    op.add_column("plants", sa.Column("icon_path", sa.Text(), nullable=True), schema=schema)


def downgrade():
    op.drop_column("plants", "icon_path", schema=schema)
