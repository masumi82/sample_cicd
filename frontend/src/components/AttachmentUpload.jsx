import { useState, useRef } from "react";
import { createAttachment, uploadToPresignedUrl } from "../api/client";

const ALLOWED_TYPES = [
  "image/jpeg",
  "image/png",
  "image/gif",
  "application/pdf",
  "text/plain",
];

export default function AttachmentUpload({ taskId, onUploaded }) {
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState(null);
  const fileInputRef = useRef(null);

  const handleUpload = async (e) => {
    const file = e.target.files[0];
    if (!file) return;

    if (!ALLOWED_TYPES.includes(file.type)) {
      setError(
        `File type "${file.type}" is not supported. Allowed: ${ALLOWED_TYPES.join(", ")}`
      );
      fileInputRef.current.value = "";
      return;
    }

    setUploading(true);
    setError(null);

    try {
      const att = await createAttachment(taskId, file.name, file.type);
      await uploadToPresignedUrl(att.upload_url, file);
      onUploaded();
    } catch (err) {
      setError(err.message);
    } finally {
      setUploading(false);
      fileInputRef.current.value = "";
    }
  };

  return (
    <div className="space-y-3">
      <label
        className={`group inline-flex cursor-pointer items-center gap-2 rounded-lg border border-dashed border-zinc-300 bg-zinc-50 px-4 py-2.5 text-sm font-medium transition-all hover:border-primary hover:bg-primary/5 hover:text-primary ${
          uploading ? "pointer-events-none opacity-60" : "text-zinc-600"
        }`}
      >
        {uploading ? (
          <div className="h-4 w-4 animate-spin rounded-full border-2 border-zinc-300 border-t-primary" />
        ) : (
          <svg className="h-4 w-4 transition-colors group-hover:text-primary" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5m-13.5-9L12 3m0 0 4.5 4.5M12 3v13.5" />
          </svg>
        )}
        {uploading ? "Uploading..." : "Upload File"}
        <input
          ref={fileInputRef}
          type="file"
          onChange={handleUpload}
          disabled={uploading}
          className="hidden"
          accept={ALLOWED_TYPES.join(",")}
        />
      </label>
      {error && (
        <div className="rounded-lg bg-red-50 px-4 py-3 text-sm text-red-600">{error}</div>
      )}
    </div>
  );
}
