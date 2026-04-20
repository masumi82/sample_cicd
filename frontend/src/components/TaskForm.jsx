import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { createTask } from "../api/client";
import {
  PillButton,
  Field,
  TextInput,
  TextArea,
  InlineBanner,
  Spinner,
} from "./ui";

export default function TaskForm() {
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!title.trim()) {
      setError("A title is required.");
      return;
    }
    setError("");
    setSubmitting(true);
    try {
      const task = await createTask({
        title: title.trim(),
        description: description.trim() || undefined,
      });
      navigate(`/tasks/${task.id}`);
    } catch (err) {
      setError(err.message);
      setSubmitting(false);
    }
  };

  return (
    <section className="mx-auto max-w-[692px] px-[22px] pt-14 pb-28 animate-[fadeInUp_420ms_cubic-bezier(0.16,1,0.3,1)]">
      <div className="mb-7">
        <button
          type="button"
          onClick={() => navigate("/")}
          className="text-[color:var(--color-apple-link)] text-sm tracking-apple hover:underline"
        >
          ‹ All tasks
        </button>
      </div>

      <div className="text-center mb-10">
        <p className="text-[17px] text-[color:var(--color-ink-1)] tracking-apple mb-2">
          New task
        </p>
        <h1 className="text-apple-h2 m-0 mb-3">What's next?</h1>
        <p className="text-apple-intro m-0">
          Give it a name. Add context if you'd like.
        </p>
      </div>

      <div className="card-apple px-9 py-8">
        <form onSubmit={handleSubmit} className="flex flex-col gap-5">
          {error && <InlineBanner tone="error">{error}</InlineBanner>}
          <Field label="Title" htmlFor="task-title" required>
            <TextInput
              id="task-title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              maxLength={255}
              placeholder="Finish the Q2 deck"
              autoFocus
            />
          </Field>
          <Field
            label="Description"
            htmlFor="task-desc"
            hint="Optional. Markdown-friendly."
          >
            <TextArea
              id="task-desc"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={5}
              placeholder="Add any context, links or notes."
            />
          </Field>
          <div className="flex justify-end gap-3 mt-1">
            <PillButton
              type="button"
              variant="ghost"
              size="md"
              onClick={() => navigate("/")}
            >
              Cancel
            </PillButton>
            <PillButton
              type="submit"
              variant="primary"
              size="md"
              disabled={submitting}
            >
              {submitting ? (
                <>
                  <Spinner size={12} color="#fff" /> Creating…
                </>
              ) : (
                <>Create task ›</>
              )}
            </PillButton>
          </div>
        </form>
      </div>
    </section>
  );
}
