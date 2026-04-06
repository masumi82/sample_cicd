"""Task CRUD endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Task
from app.schemas import TaskCreate, TaskResponse, TaskUpdate
from app.services.events import publish_task_completed, publish_task_created

router = APIRouter()


@router.get("", response_model=list[TaskResponse])
def list_tasks(db: Session = Depends(get_db)) -> list[Task]:
    """Return all tasks.

    Args:
        db: Database session.

    Returns:
        List of all tasks.
    """
    return db.query(Task).all()


@router.post("", response_model=TaskResponse, status_code=status.HTTP_201_CREATED)
def create_task(task_in: TaskCreate, db: Session = Depends(get_db)) -> Task:
    """Create a new task.

    Args:
        task_in: Task creation data.
        db: Database session.

    Returns:
        The created task.
    """
    task = Task(title=task_in.title, description=task_in.description)
    db.add(task)
    db.commit()
    db.refresh(task)
    publish_task_created(task.id, task.title)
    return task


@router.get("/{task_id}", response_model=TaskResponse)
def get_task(task_id: int, db: Session = Depends(get_db)) -> Task:
    """Get a single task by ID.

    Args:
        task_id: The task ID.
        db: Database session.

    Returns:
        The requested task.

    Raises:
        HTTPException: If task not found.
    """
    task = db.query(Task).filter(Task.id == task_id).first()
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    return task


@router.put("/{task_id}", response_model=TaskResponse)
def update_task(
    task_id: int, task_in: TaskUpdate, db: Session = Depends(get_db)
) -> Task:
    """Update an existing task (partial update).

    Args:
        task_id: The task ID.
        task_in: Task update data (only provided fields are updated).
        db: Database session.

    Returns:
        The updated task.

    Raises:
        HTTPException: If task not found.
    """
    task = db.query(Task).filter(Task.id == task_id).first()
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")

    was_completed = task.completed
    update_data = task_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(task, field, value)

    db.commit()
    db.refresh(task)

    if task.completed and not was_completed:
        publish_task_completed(task.id, task.title)

    return task


@router.delete("/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_task(task_id: int, db: Session = Depends(get_db)) -> None:
    """Delete a task by ID.

    Args:
        task_id: The task ID.
        db: Database session.

    Raises:
        HTTPException: If task not found.
    """
    task = db.query(Task).filter(Task.id == task_id).first()
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")

    db.delete(task)
    db.commit()
