import { useState, useEffect } from "react";
import { getAttachments, getAttachment, deleteAttachment } from "../api/client";

export default function AttachmentList({ taskId, refreshKey }) {
  const [attachments, setAttachments] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    setLoading(true);
    getAttachments(taskId)
      .then(setAttachments)
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, [taskId, refreshKey]);

  const handleDownload = async (attachmentId) => {
    try {
      const att = await getAttachment(taskId, attachmentId);
      if (att.download_url) {
        window.open(att.download_url, "_blank");
      }
    } catch (err) {
      setError(err.message);
    }
  };

  const handleDelete = async (attachmentId) => {
    if (!window.confirm("Delete this attachment?")) return;
    try {
      await deleteAttachment(taskId, attachmentId);
      setAttachments((prev) => prev.filter((a) => a.id !== attachmentId));
    } catch (err) {
      setError(err.message);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-6">
        <div className="h-5 w-5 animate-spin rounded-full border-2 border-zinc-200 border-t-primary" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="rounded-lg bg-red-50 px-4 py-3 text-sm text-red-600">{error}</div>
    );
  }

  if (attachments.length === 0) {
    return (
      <div className="rounded-lg border border-dashed border-zinc-200 py-8 text-center">
        <svg className="mx-auto h-8 w-8 text-zinc-300" fill="none" stroke="currentColor" strokeWidth="1.5" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" d="m18.375 12.739-7.693 7.693a4.5 4.5 0 0 1-6.364-6.364l10.94-10.94A3 3 0 1 1 19.5 7.372L8.552 18.32m.009-.01-.01.01m5.699-9.941-7.81 7.81a1.5 1.5 0 0 0 2.112 2.13" />
        </svg>
        <p className="mt-2 text-sm text-zinc-400">No attachments yet</p>
      </div>
    );
  }

  return (
    <ul className="divide-y divide-zinc-100">
      {attachments.map((att) => (
        <li key={att.id} className="flex items-center gap-3 py-3 first:pt-0 last:pb-0">
          {/* File icon */}
          <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-zinc-100">
            <svg className="h-4.5 w-4.5 text-zinc-500" fill="none" stroke="currentColor" strokeWidth="1.5" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z" />
            </svg>
          </div>

          {/* File info */}
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-medium text-zinc-800">{att.filename}</p>
            <p className="text-xs text-zinc-400">
              {att.content_type} &middot; {new Date(att.created_at).toLocaleDateString()}
            </p>
          </div>

          {/* Actions */}
          <div className="flex shrink-0 items-center gap-1.5">
            <button
              onClick={() => handleDownload(att.id)}
              className="inline-flex items-center gap-1.5 rounded-md border border-zinc-200 bg-white px-2.5 py-1.5 text-xs font-medium text-zinc-600 transition-colors hover:bg-zinc-50 hover:text-zinc-900"
            >
              <svg className="h-3.5 w-3.5" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5M16.5 12 12 16.5m0 0L7.5 12m4.5 4.5V3" />
              </svg>
              Download
            </button>
            <button
              onClick={() => handleDelete(att.id)}
              className="inline-flex items-center gap-1.5 rounded-md border border-red-200 bg-white px-2.5 py-1.5 text-xs font-medium text-danger transition-colors hover:bg-red-50"
            >
              <svg className="h-3.5 w-3.5" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0" />
              </svg>
              Delete
            </button>
          </div>
        </li>
      ))}
    </ul>
  );
}
