import { useState, useEffect } from "react";
import { getAttachments, getAttachment, deleteAttachment } from "../api/client";
import { InlineBanner, Spinner } from "./ui";

function FileIcon({ type }) {
  const isImage = type && type.startsWith("image/");
  const isPdf = type === "application/pdf";
  const tint = isImage ? "#34c759" : isPdf ? "#ff3b30" : "#0071e3";
  return (
    <div
      className="w-10 h-10 rounded-[10px] flex items-center justify-center shrink-0"
      style={{
        background: `${tint}14`,
        color: tint,
      }}
      aria-hidden="true"
    >
      <svg
        width="18"
        height="18"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
        <path d="M14 2v6h6" />
      </svg>
    </div>
  );
}

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
        <Spinner size={20} color="var(--color-apple-blue)" />
      </div>
    );
  }

  if (error) {
    return <InlineBanner tone="error">{error}</InlineBanner>;
  }

  if (attachments.length === 0) {
    return null;
  }

  return (
    <ul className="m-0 p-0 list-none">
      {attachments.map((att) => (
        <li
          key={att.id}
          className="grid grid-cols-[auto_1fr_auto] gap-3.5 items-center py-3.5 border-b border-black/8 last:border-b-0"
        >
          <FileIcon type={att.content_type} />
          <div className="min-w-0">
            <p className="text-[15px] tracking-tight text-[color:var(--color-ink-1)] truncate m-0">
              {att.filename}
            </p>
            <p className="text-[12px] text-[color:var(--color-ink-3)] tracking-tight mt-0.5 m-0">
              {att.content_type} · {new Date(att.created_at).toLocaleDateString()}
            </p>
          </div>
          <div className="flex gap-2.5 items-center">
            <button
              type="button"
              onClick={() => handleDownload(att.id)}
              className="text-[color:var(--color-apple-link)] text-[13px] tracking-tight hover:underline bg-transparent border-0 p-0 cursor-pointer"
            >
              Download
            </button>
            <button
              type="button"
              onClick={() => handleDelete(att.id)}
              className="text-[color:var(--color-apple-red-strong)] text-[13px] tracking-tight hover:underline bg-transparent border-0 p-0 cursor-pointer"
            >
              Delete
            </button>
          </div>
        </li>
      ))}
    </ul>
  );
}
