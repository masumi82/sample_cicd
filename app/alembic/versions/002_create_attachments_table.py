"""Create attachments table.

Revision ID: 002
Revises: 001
Create Date: 2026-04-06
"""

import sqlalchemy as sa
from alembic import op

revision = "002"
down_revision = "001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Create attachments table."""
    op.create_table(
        "attachments",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column(
            "task_id",
            sa.Integer,
            sa.ForeignKey("tasks.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("filename", sa.String(255), nullable=False),
        sa.Column("content_type", sa.String(100), nullable=False),
        sa.Column("s3_key", sa.String(512), nullable=False),
        sa.Column("file_size", sa.BigInteger, nullable=True),
        sa.Column(
            "created_at", sa.DateTime, nullable=False, server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime, nullable=False, server_default=sa.func.now()
        ),
    )
    op.create_index("ix_attachments_id", "attachments", ["id"])
    op.create_index("ix_attachments_task_id", "attachments", ["task_id"])


def downgrade() -> None:
    """Drop attachments table."""
    op.drop_index("ix_attachments_task_id", table_name="attachments")
    op.drop_index("ix_attachments_id", table_name="attachments")
    op.drop_table("attachments")
