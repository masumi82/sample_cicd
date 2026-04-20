import { useState, useRef } from "react";
import { createAttachment, uploadToPresignedUrl } from "../api/client";
import { InlineBanner, Spinner } from "./ui";

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
  const [drag, setDrag] = useState(false);
  const fileInputRef = useRef(null);

  const handleFile = async (file) => {
    if (!file) return;

    if (!ALLOWED_TYPES.includes(file.type)) {
      setError(
        `File type "${file.type}" is not supported. Allowed: ${ALLOWED_TYPES.join(", ")}`
      );
      if (fileInputRef.current) fileInputRef.current.value = "";
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
      if (fileInputRef.current) fileInputRef.current.value = "";
    }
  };

  const handlePick = () => {
    if (!uploading && fileInputRef.current) fileInputRef.current.click();
  };

  return (
    <div className="flex flex-col gap-3">
      <div
        role="button"
        tabIndex={0}
        onClick={handlePick}
        onKeyDown={(e) => {
          if (e.key === "Enter" || e.key === " ") {
            e.preventDefault();
            handlePick();
          }
        }}
        onDragOver={(e) => {
          e.preventDefault();
          setDrag(true);
        }}
        onDragLeave={() => setDrag(false)}
        onDrop={(e) => {
          e.preventDefault();
          setDrag(false);
          const file = e.dataTransfer.files?.[0];
          if (file) handleFile(file);
        }}
        className={`rounded-[18px] px-[22px] py-7 text-center cursor-pointer transition-all duration-200 ease-[var(--ease-apple)] ${
          drag
            ? "border-[1.5px] border-dashed border-[var(--color-apple-blue)] bg-[rgba(0,113,227,0.04)]"
            : "border-[1.5px] border-dashed border-[var(--color-border-ap)] bg-[var(--color-bg-light)]"
        } ${uploading ? "pointer-events-none opacity-60" : ""}`}
      >
        {uploading ? (
          <div className="flex items-center justify-center gap-2">
            <Spinner size={16} color="var(--color-apple-blue)" />
            <span className="text-apple-body">Uploading…</span>
          </div>
        ) : (
          <>
            <p className="text-[17px] tracking-apple text-[color:var(--color-ink-1)] m-0 mb-1">
              Drop a file to attach.
            </p>
            <p className="text-[13px] text-[color:var(--color-ink-3)] tracking-tight m-0">
              Or{" "}
              <span className="text-[color:var(--color-apple-link)]">choose a file</span>
              {" · "}JPG, PNG, GIF, PDF, TXT
            </p>
          </>
        )}
        <input
          ref={fileInputRef}
          type="file"
          className="hidden"
          accept={ALLOWED_TYPES.join(",")}
          disabled={uploading}
          onChange={(e) => handleFile(e.target.files?.[0])}
        />
      </div>

      {error && <InlineBanner tone="error">{error}</InlineBanner>}
    </div>
  );
}
