import { useState, useEffect, useCallback } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { getTask, updateTask, deleteTask } from "../api/client";
import AttachmentList from "./AttachmentList";
import AttachmentUpload from "./AttachmentUpload";

export default function TaskDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [task, setTask] = useState(null);
  const [editing, setEditing] = useState(false);
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [refreshKey, setRefreshKey] = useState(0);

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
    } catch (err) {
      setError(err.message);
    }
  };

  const handleDelete = async () => {
    if (!window.confirm("Are you sure you want to delete this task?")) return;
    try {
      await deleteTask(id);
      navigate("/");
    } catch (err) {
      setError(err.message);
    }
  };

  const handleToggleComplete = () => {
    handleUpdate({ completed: !task.completed });
  };

  const handleSaveEdit = (e) => {
    e.preventDefault();
    if (!title.trim()) return;
    handleUpdate({ title: title.trim(), description: description.trim() || null });
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-zinc-200 border-t-primary" />
      </div>
    );
  }

  if (error && !task) {
    return (
      <div className="rounded-xl border border-red-200 bg-red-50 p-6 text-center text-sm text-red-600">
        Error: {error}
      </div>
    );
  }

  if (!task) {
    return (
      <div className="rounded-xl border border-zinc-200 bg-white p-6 text-center text-sm text-zinc-500">
        Task not found.
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Back link */}
      <button
        onClick={() => navigate("/")}
        className="inline-flex items-center gap-1.5 text-sm text-zinc-500 transition-colors hover:text-zinc-900"
      >
        <svg className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5" />
        </svg>
        Back to tasks
      </button>

      {error && (
        <div className="rounded-lg bg-red-50 px-4 py-3 text-sm text-red-600">{error}</div>
      )}

      {/* Task Card */}
      <div className="rounded-xl border border-zinc-200 bg-white shadow-sm">
        {editing ? (
          /* Edit Mode */
          <form onSubmit={handleSaveEdit} className="p-6 space-y-5">
            <div>
              <label htmlFor="edit-title" className="block text-sm font-semibold text-zinc-700">
                Title <span className="text-danger">*</span>
              </label>
              <input
                id="edit-title"
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                maxLength={255}
                autoFocus
                className="mt-1.5 block w-full rounded-lg border border-zinc-300 bg-white px-3.5 py-2.5 text-sm text-zinc-900 shadow-sm transition-all placeholder:text-zinc-400 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
              />
            </div>
            <div>
              <label htmlFor="edit-description" className="block text-sm font-semibold text-zinc-700">
                Description
              </label>
              <textarea
                id="edit-description"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                rows={4}
                className="mt-1.5 block w-full rounded-lg border border-zinc-300 bg-white px-3.5 py-2.5 text-sm text-zinc-900 shadow-sm transition-all placeholder:text-zinc-400 focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20 resize-none"
              />
            </div>
            <div className="flex items-center gap-3">
              <button
                type="submit"
                className="rounded-lg bg-primary px-5 py-2.5 text-sm font-semibold text-white shadow-sm transition-all hover:bg-primary-hover active:scale-[0.98]"
              >
                Save Changes
              </button>
              <button
                type="button"
                onClick={() => setEditing(false)}
                className="rounded-lg border border-zinc-300 bg-white px-5 py-2.5 text-sm font-medium text-zinc-700 shadow-sm transition-all hover:bg-zinc-50"
              >
                Cancel
              </button>
            </div>
          </form>
        ) : (
          /* View Mode */
          <div className="p-6">
            {/* Header */}
            <div className="flex items-start justify-between gap-4">
              <div className="min-w-0 flex-1">
                <h2 className={`text-xl font-bold ${task.completed ? "text-zinc-400 line-through" : "text-zinc-900"}`}>
                  {task.title}
                </h2>
                <div className="mt-2 flex flex-wrap items-center gap-2">
                  <span
                    className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-semibold ${
                      task.completed
                        ? "bg-emerald-50 text-emerald-700"
                        : "bg-amber-50 text-amber-700"
                    }`}
                  >
                    <span className={`h-1.5 w-1.5 rounded-full ${task.completed ? "bg-emerald-500" : "bg-amber-500"}`} />
                    {task.completed ? "Completed" : "Pending"}
                  </span>
                </div>
              </div>
            </div>

            {/* Description */}
            {task.description && (
              <p className="mt-4 whitespace-pre-wrap text-sm leading-relaxed text-zinc-600">
                {task.description}
              </p>
            )}

            {/* Meta */}
            <div className="mt-4 flex flex-wrap gap-x-6 gap-y-1 text-xs text-zinc-400">
              <span>Created: {new Date(task.created_at).toLocaleString()}</span>
              <span>Updated: {new Date(task.updated_at).toLocaleString()}</span>
            </div>

            {/* Actions */}
            <div className="mt-6 flex flex-wrap gap-2 border-t border-zinc-100 pt-4">
              <button
                onClick={handleToggleComplete}
                className={`inline-flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-medium shadow-sm transition-all active:scale-[0.98] ${
                  task.completed
                    ? "border border-zinc-300 bg-white text-zinc-700 hover:bg-zinc-50"
                    : "bg-success text-white hover:bg-emerald-600"
                }`}
              >
                <svg className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" />
                </svg>
                {task.completed ? "Mark Pending" : "Mark Complete"}
              </button>
              <button
                onClick={() => setEditing(true)}
                className="inline-flex items-center gap-2 rounded-lg border border-zinc-300 bg-white px-4 py-2 text-sm font-medium text-zinc-700 shadow-sm transition-all hover:bg-zinc-50 active:scale-[0.98]"
              >
                <svg className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L10.582 16.07a4.5 4.5 0 0 1-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 0 1 1.13-1.897l8.932-8.931Z" />
                </svg>
                Edit
              </button>
              <button
                onClick={handleDelete}
                className="inline-flex items-center gap-2 rounded-lg border border-red-200 bg-white px-4 py-2 text-sm font-medium text-danger shadow-sm transition-all hover:bg-red-50 active:scale-[0.98]"
              >
                <svg className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0" />
                </svg>
                Delete
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Attachments Section */}
      <div className="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
        <div className="flex items-center justify-between">
          <h3 className="text-lg font-bold text-zinc-900">Attachments</h3>
        </div>
        <div className="mt-4">
          <AttachmentUpload taskId={id} onUploaded={() => setRefreshKey((k) => k + 1)} />
        </div>
        <div className="mt-4">
          <AttachmentList taskId={id} refreshKey={refreshKey} />
        </div>
      </div>
    </div>
  );
}
