"""Create tasks table.

Revision ID: 001
Revises:
Create Date: 2026-04-03
"""

import sqlalchemy as sa
from alembic import op

revision = "001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Create tasks table."""
    op.create_table(
        "tasks",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("description", sa.Text, nullable=True),
        sa.Column("completed", sa.Boolean, nullable=False, server_default="false"),
        sa.Column(
            "created_at", sa.DateTime, nullable=False, server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime, nullable=False, server_default=sa.func.now()
        ),
    )
    op.create_index("ix_tasks_id", "tasks", ["id"])


def downgrade() -> None:
    """Drop tasks table."""
    op.drop_index("ix_tasks_id", table_name="tasks")
    op.drop_table("tasks")
