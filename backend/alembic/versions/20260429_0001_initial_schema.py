from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from app.core.config import get_settings


revision = "20260429_0001"
down_revision = None
branch_labels = None
depends_on = None


settings = get_settings()
schema = settings.database_schema


def upgrade():
    op.execute(sa.text(f'CREATE SCHEMA IF NOT EXISTS "{schema}"'))

    op.create_table(
        "plants",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("pet_name", sa.String(length=120), nullable=False),
        sa.Column("location", sa.String(length=24), nullable=False),
        sa.Column("room_location", sa.String(length=120), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("common_name", sa.String(length=160), nullable=True),
        sa.Column("scientific_name", sa.String(length=180), nullable=True),
        sa.Column("health_score", sa.Integer(), nullable=True),
        sa.Column("latest_photo_id", sa.String(length=36), nullable=True),
        sa.Column("archived", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        schema=schema,
    )

    op.create_table(
        "plant_photos",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("plant_id", sa.String(length=36), nullable=False),
        sa.Column("original_path", sa.Text(), nullable=False),
        sa.Column("thumb_256_path", sa.Text(), nullable=True),
        sa.Column("thumb_768_path", sa.Text(), nullable=True),
        sa.Column("mime_type", sa.String(length=80), nullable=False),
        sa.Column("width", sa.Integer(), nullable=True),
        sa.Column("height", sa.Integer(), nullable=True),
        sa.Column("file_size_bytes", sa.Integer(), nullable=True),
        sa.Column("checksum_sha256", sa.String(length=64), nullable=True),
        sa.Column("is_registration_photo", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["plant_id"], [f"{schema}.plants.id"], ondelete="CASCADE"),
        schema=schema,
    )
    op.create_index("ix_plant_photos_plant_id", "plant_photos", ["plant_id"], schema=schema)
    op.create_index("ix_plant_photos_checksum_sha256", "plant_photos", ["checksum_sha256"], schema=schema)

    op.create_foreign_key(
        "fk_plants_latest_photo_id",
        "plants",
        "plant_photos",
        ["latest_photo_id"],
        ["id"],
        source_schema=schema,
        referent_schema=schema,
        ondelete="SET NULL",
    )

    op.create_table(
        "plant_analysis",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("plant_id", sa.String(length=36), nullable=False),
        sa.Column("photo_id", sa.String(length=36), nullable=True),
        sa.Column("status", sa.String(length=24), nullable=False),
        sa.Column("common_name", sa.String(length=160), nullable=True),
        sa.Column("scientific_name", sa.String(length=180), nullable=True),
        sa.Column("confidence", sa.Float(), nullable=True),
        sa.Column("health_score", sa.Integer(), nullable=True),
        sa.Column("health_notes", sa.Text(), nullable=True),
        sa.Column("raw_response", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["plant_id"], [f"{schema}.plants.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["photo_id"], [f"{schema}.plant_photos.id"], ondelete="SET NULL"),
        schema=schema,
    )
    op.create_index("ix_plant_analysis_plant_id", "plant_analysis", ["plant_id"], schema=schema)

    op.create_table(
        "care_plans",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("plant_id", sa.String(length=36), nullable=False),
        sa.Column("analysis_id", sa.String(length=36), nullable=True),
        sa.Column("watering", sa.Text(), nullable=True),
        sa.Column("fertilizing", sa.Text(), nullable=True),
        sa.Column("sunlight", sa.Text(), nullable=True),
        sa.Column("repotting", sa.Text(), nullable=True),
        sa.Column("soil", sa.Text(), nullable=True),
        sa.Column("raw_plan", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["plant_id"], [f"{schema}.plants.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["analysis_id"], [f"{schema}.plant_analysis.id"], ondelete="SET NULL"),
        schema=schema,
    )
    op.create_index("ix_care_plans_plant_id", "care_plans", ["plant_id"], schema=schema)

    op.create_table(
        "care_tasks",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("plant_id", sa.String(length=36), nullable=False),
        sa.Column("care_plan_id", sa.String(length=36), nullable=True),
        sa.Column("task_type", sa.String(length=40), nullable=False),
        sa.Column("title", sa.String(length=160), nullable=False),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("frequency_days", sa.Integer(), nullable=True),
        sa.Column("next_due_date", sa.Date(), nullable=True),
        sa.Column("enabled", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("user_override", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["plant_id"], [f"{schema}.plants.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["care_plan_id"], [f"{schema}.care_plans.id"], ondelete="SET NULL"),
        schema=schema,
    )
    op.create_index("ix_care_tasks_plant_id", "care_tasks", ["plant_id"], schema=schema)
    op.create_index("ix_care_tasks_next_due_date", "care_tasks", ["next_due_date"], schema=schema)

    op.create_table(
        "task_events",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("task_id", sa.String(length=36), nullable=False),
        sa.Column("plant_id", sa.String(length=36), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("due_date", sa.Date(), nullable=True),
        sa.Column("was_late", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["task_id"], [f"{schema}.care_tasks.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["plant_id"], [f"{schema}.plants.id"], ondelete="CASCADE"),
        schema=schema,
    )
    op.create_index("ix_task_events_task_id", "task_events", ["task_id"], schema=schema)
    op.create_index("ix_task_events_plant_id", "task_events", ["plant_id"], schema=schema)

    op.create_table(
        "ai_chat_sessions",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("plant_id", sa.String(length=36), nullable=False),
        sa.Column("title", sa.String(length=160), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["plant_id"], [f"{schema}.plants.id"], ondelete="CASCADE"),
        schema=schema,
    )
    op.create_index("ix_ai_chat_sessions_plant_id", "ai_chat_sessions", ["plant_id"], schema=schema)

    op.create_table(
        "ai_chat_messages",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("session_id", sa.String(length=36), nullable=False),
        sa.Column("role", sa.String(length=24), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("prompt_context", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["session_id"], [f"{schema}.ai_chat_sessions.id"], ondelete="CASCADE"),
        schema=schema,
    )
    op.create_index("ix_ai_chat_messages_session_id", "ai_chat_messages", ["session_id"], schema=schema)

    op.create_table(
        "background_jobs",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("job_type", sa.String(length=60), nullable=False),
        sa.Column("status", sa.String(length=24), nullable=False),
        sa.Column("plant_id", sa.String(length=36), nullable=True),
        sa.Column("photo_id", sa.String(length=36), nullable=True),
        sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("last_error", sa.Text(), nullable=True),
        sa.Column("payload", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("finished_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["plant_id"], [f"{schema}.plants.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["photo_id"], [f"{schema}.plant_photos.id"], ondelete="SET NULL"),
        schema=schema,
    )
    op.create_index("ix_background_jobs_job_type", "background_jobs", ["job_type"], schema=schema)
    op.create_index("ix_background_jobs_status", "background_jobs", ["status"], schema=schema)
    op.create_index("ix_background_jobs_plant_id", "background_jobs", ["plant_id"], schema=schema)


def downgrade():
    op.drop_index("ix_background_jobs_plant_id", table_name="background_jobs", schema=schema)
    op.drop_index("ix_background_jobs_status", table_name="background_jobs", schema=schema)
    op.drop_index("ix_background_jobs_job_type", table_name="background_jobs", schema=schema)
    op.drop_table("background_jobs", schema=schema)
    op.drop_index("ix_ai_chat_messages_session_id", table_name="ai_chat_messages", schema=schema)
    op.drop_table("ai_chat_messages", schema=schema)
    op.drop_index("ix_ai_chat_sessions_plant_id", table_name="ai_chat_sessions", schema=schema)
    op.drop_table("ai_chat_sessions", schema=schema)
    op.drop_index("ix_task_events_plant_id", table_name="task_events", schema=schema)
    op.drop_index("ix_task_events_task_id", table_name="task_events", schema=schema)
    op.drop_table("task_events", schema=schema)
    op.drop_index("ix_care_tasks_next_due_date", table_name="care_tasks", schema=schema)
    op.drop_index("ix_care_tasks_plant_id", table_name="care_tasks", schema=schema)
    op.drop_table("care_tasks", schema=schema)
    op.drop_index("ix_care_plans_plant_id", table_name="care_plans", schema=schema)
    op.drop_table("care_plans", schema=schema)
    op.drop_index("ix_plant_analysis_plant_id", table_name="plant_analysis", schema=schema)
    op.drop_table("plant_analysis", schema=schema)
    op.drop_constraint("fk_plants_latest_photo_id", "plants", schema=schema, type_="foreignkey")
    op.drop_index("ix_plant_photos_checksum_sha256", table_name="plant_photos", schema=schema)
    op.drop_index("ix_plant_photos_plant_id", table_name="plant_photos", schema=schema)
    op.drop_table("plant_photos", schema=schema)
    op.drop_table("plants", schema=schema)
