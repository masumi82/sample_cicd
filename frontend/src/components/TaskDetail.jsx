import { useState, useEffect, useCallback } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { getTask, updateTask, deleteTask } from "../api/client";
import AttachmentList from "./AttachmentList";
import AttachmentUpload from "./AttachmentUpload";
import {
  PillButton,
  Field,
  TextInput,
  TextArea,
  InlineBanner,
  Spinner,
  StatusDisc,
} from "./ui";

function DeleteConfirmModal({ onCancel, onConfirm }) {
  return (
    <div
      className="fixed inset-0 z-[200] bg-black/45 flex items-center justify-center p-[22px]"
      style={{ backdropFilter: "blur(6px)", WebkitBackdropFilter: "blur(6px)" }}
      onClick={onCancel}
    >
      <div
        className="card-apple w-full max-w-[440px] px-9 py-8 text-center shadow-[0_30px_60px_rgba(0,0,0,0.3)]"
        onClick={(e) => e.stopPropagation()}
      >
        <h3 className="text-[24px] font-semibold tracking-apple-tight m-0 mb-2">
          Delete this task?
        </h3>
        <p className="text-[15px] text-[color:var(--color-ink-2)] tracking-tight m-0 mb-6">
          This can't be undone. Attachments will be removed as well.
        </p>
        <div className="flex gap-3 justify-center">
          <PillButton variant="ghost" size="md" onClick={onCancel}>
            Cancel
          </PillButton>
          <PillButton variant="danger-solid" size="md" onClick={onConfirm}>
            Delete task
          </PillButton>
        </div>
      </div>
    </div>
  );
}

export default function TaskDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [task, setTask] = useState(null);
  const [editing, setEditing] = useState(false);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [editError, setEditError] = useState("");
  const [refreshKey, setRefreshKey] = useState(0);
  const [confirmDelete, setConfirmDelete] = useState(false);

  const loadTask = useCallback(() => {
    setLoading(true);
    getTask(id)
      .then((t) => {
        setTask(t);
        setTitle(t.title);
        setDescription(t.description || "");
      })
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, [id]);

  useEffect(() => {
    loadTask();
  }, [loadTask]);

  const handleUpdate = async (data) => {
    try {
      const updated = await updateTask(id, data);
      setTask(updated);
      setTitle(updated.title);
      setDescription(updated.description || "");
      setEditing(false);
      setEditError("");
    } catch (err) {
      setError(err.message);
    }
  };

  const handleDelete = async () => {
    try {
      await deleteTask(id);
      navigate("/");
    } catch (err) {
      setError(err.message);
      setConfirmDelete(false);
    }
  };

  const handleToggleComplete = () => {
    handleUpdate({ completed: !task.completed });
  };

  const handleSaveEdit = (e) => {
    e.preventDefault();
    if (!title.trim()) {
      setEditError("Title is required.");
      return;
    }
    setEditError("");
    handleUpdate({
      title: title.trim(),
      description: description.trim() || null,
    });
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-24">
        <Spinner size={28} color="var(--color-apple-blue)" />
      </div>
    );
  }

  if (error && !task) {
    return (
      <section className="mx-auto max-w-[692px] px-[22px] pt-14 pb-24">
        <InlineBanner tone="error">Error: {error}</InlineBanner>
      </section>
    );
  }

  if (!task) {
    return (
      <section className="mx-auto max-w-[692px] px-[22px] pt-14 pb-24">
        <div className="card-apple px-9 py-10 text-center text-[color:var(--color-ink-2)]">
          Task not found.
        </div>
      </section>
    );
  }

  return (
    <section className="mx-auto max-w-[720px] px-[22px] pt-10 pb-28 animate-[fadeInUp_420ms_cubic-bezier(0.16,1,0.3,1)]">
      <div className="mb-6">
        <button
          type="button"
          onClick={() => navigate("/")}
          className="text-[color:var(--color-apple-link)] text-sm tracking-apple hover:underline"
        >
          ‹ All tasks
        </button>
      </div>

      {error && (
        <div className="mb-6">
          <InlineBanner tone="error">{error}</InlineBanner>
        </div>
      )}

      {/* Hero card */}
      <div className="card-apple px-10 py-10 mb-6">
        {editing ? (
          <form onSubmit={handleSaveEdit} className="flex flex-col gap-5">
            {editError && <InlineBanner tone="error">{editError}</InlineBanner>}
            <Field label="Title" htmlFor="edit-title" required>
              <TextInput
                id="edit-title"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                autoFocus
                maxLength={255}
              />
            </Field>
            <Field label="Description" htmlFor="edit-desc">
              <TextArea
                id="edit-desc"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                rows={5}
              />
            </Field>
            <div className="flex justify-end gap-3">
              <PillButton
                type="button"
                variant="ghost"
                size="md"
                onClick={() => {
                  setTitle(task.title);
                  setDescription(task.description || "");
                  setEditing(false);
                  setEditError("");
                }}
              >
                Cancel
              </PillButton>
              <PillButton type="submit" variant="primary" size="md">
                Save changes ›
              </PillButton>
            </div>
          </form>
        ) : (
          <>
            <div className="flex gap-4 items-start">
              <div className="pt-2">
                <StatusDisc
                  completed={task.completed}
                  onClick={handleToggleComplete}
                  size={28}
                />
              </div>
              <div className="flex-1 min-w-0">
                <p
                  className={`text-[13px] tracking-tight uppercase font-medium mb-1.5 ${
                    task.completed
                      ? "text-[color:var(--color-apple-green)]"
                      : "text-[color:var(--color-apple-orange)]"
                  }`}
                >
                  {task.completed ? "Completed" : "Active"}
                </p>
                <h1
                  className={`text-apple-h2 m-0 break-words ${
                    task.completed
                      ? "text-[color:var(--color-ink-3)] line-through"
                      : "text-[color:var(--color-ink-1)]"
                  }`}
                >
                  {task.title}
                </h1>
              </div>
            </div>

            {task.description && (
              <p className="mt-6 ml-11 text-apple-body text-[color:var(--color-ink-1)] whitespace-pre-wrap">
                {task.description}
              </p>
            )}

            <div className="mt-7 ml-11 flex gap-6 flex-wrap text-apple-caption">
              <span>Created {new Date(task.created_at).toLocaleString()}</span>
              <span>Updated {new Date(task.updated_at).toLocaleString()}</span>
            </div>

            <div className="mt-7 ml-11 flex gap-2.5 flex-wrap">
              <PillButton
                variant={task.completed ? "ghost" : "primary"}
                size="md"
                onClick={handleToggleComplete}
              >
                {task.completed ? "Mark active" : "Mark complete ›"}
              </PillButton>
              <PillButton
                variant="ghost"
                size="md"
                onClick={() => setEditing(true)}
              >
                Edit
              </PillButton>
              <PillButton
                variant="danger"
                size="md"
                onClick={() => setConfirmDelete(true)}
              >
                Delete
              </PillButton>
            </div>
          </>
        )}
      </div>

      {/* Attachments card */}
      <div className="card-apple px-9 py-8">
        <div className="flex items-baseline justify-between mb-5">
          <h2 className="text-[28px] font-semibold tracking-apple-headline leading-tight m-0">
            Attachments.
          </h2>
        </div>

        <AttachmentUpload
          taskId={id}
          onUploaded={() => setRefreshKey((k) => k + 1)}
        />

        <div className="mt-4">
          <AttachmentList taskId={id} refreshKey={refreshKey} />
        </div>
      </div>

      {confirmDelete && (
        <DeleteConfirmModal
          onCancel={() => setConfirmDelete(false)}
          onConfirm={handleDelete}
        />
      )}
    </section>
  );
}
