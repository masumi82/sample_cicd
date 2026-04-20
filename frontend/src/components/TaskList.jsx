import { useState, useEffect } from "react";
import { Link, useNavigate } from "react-router-dom";
import { getTasks } from "../api/client";
import {
  PillButton,
  InlineBanner,
  Spinner,
  StatusDisc,
} from "./ui";

const FILTERS = [
  { key: "all", label: "All" },
  { key: "pending", label: "Active" },
  { key: "completed", label: "Completed" },
];

function heroTitle(activeCount) {
  if (activeCount === 0) return "All caught up.";
  if (activeCount === 1) return "One thing today.";
  return `${activeCount} things today.`;
}

function TaskRow({ task, onOpen }) {
  const handleActivate = (e) => {
    if (e.target.closest("button")) return;
    onOpen(task);
  };
  return (
    <div
      role="link"
      tabIndex={0}
      onClick={handleActivate}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          onOpen(task);
        }
      }}
      className="w-full grid grid-cols-[auto_1fr_auto_auto] items-center gap-4 py-[18px] px-1 border-b border-black/8 last:border-b-0 transition-colors hover:bg-black/[0.015] cursor-pointer focus:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-apple-blue)] rounded-md"
    >
      <StatusDisc completed={task.completed} />
      <div className="min-w-0">
        <div
          className={`text-[17px] tracking-apple font-normal truncate ${
            task.completed
              ? "text-[color:var(--color-ink-3)] line-through"
              : "text-[color:var(--color-ink-1)]"
          }`}
        >
          {task.title}
        </div>
        {task.description && (
          <div className="text-[13px] text-[color:var(--color-ink-3)] tracking-tight mt-0.5 truncate">
            {task.description}
          </div>
        )}
      </div>
      <div className="text-apple-caption">
        {new Date(task.created_at).toLocaleDateString(undefined, {
          month: "short",
          day: "numeric",
        })}
      </div>
      <span className="text-[color:var(--color-gray-3)] text-base leading-none">›</span>
    </div>
  );
}

export default function TaskList() {
  const [tasks, setTasks] = useState([]);
  const [filter, setFilter] = useState("all");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const navigate = useNavigate();

  useEffect(() => {
    getTasks()
      .then(setTasks)
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, []);

  const filtered = tasks.filter((t) => {
    if (filter === "pending") return !t.completed;
    if (filter === "completed") return t.completed;
    return true;
  });
  const activeCount = tasks.filter((t) => !t.completed).length;

  if (loading) {
    return (
      <div className="flex items-center justify-center py-24">
        <Spinner size={28} color="var(--color-apple-blue)" />
      </div>
    );
  }

  if (error) {
    return (
      <section className="mx-auto max-w-[692px] px-[22px] pt-14 pb-24">
        <InlineBanner tone="error">Error: {error}</InlineBanner>
      </section>
    );
  }

  return (
    <section className="mx-auto max-w-[980px] px-[22px] pt-16 pb-28 animate-[fadeInUp_420ms_cubic-bezier(0.16,1,0.3,1)]">
      {/* Hero */}
      <div className="text-center mb-14">
        <p className="text-[17px] text-[color:var(--color-ink-1)] tracking-apple mb-2">
          Your tasks
        </p>
        <h1 className="text-apple-hero m-0 mb-4">{heroTitle(activeCount)}</h1>
        <p className="text-apple-intro max-w-[560px] mx-auto mb-7">
          Organize what matters. Attach what counts. Finish what you start.
        </p>
        <div className="flex gap-3.5 justify-center flex-wrap">
          <PillButton
            variant="primary"
            size="md"
            onClick={() => navigate("/tasks/new")}
          >
            <span className="text-base leading-none">+</span> New task
          </PillButton>
        </div>
      </div>

      {/* Segmented filter */}
      <div className="flex justify-center mb-7">
        <div className="inline-flex bg-[var(--color-bg-gray)] pill p-1 gap-0.5">
          {FILTERS.map((f) => {
            const active = filter === f.key;
            const count =
              f.key === "all"
                ? tasks.length
                : f.key === "pending"
                ? activeCount
                : tasks.length - activeCount;
            return (
              <button
                key={f.key}
                type="button"
                onClick={() => setFilter(f.key)}
                className={`pill px-5 py-2 text-[13px] tracking-tight border-0 cursor-pointer transition-all duration-200 ease-[var(--ease-apple)] ${
                  active
                    ? "bg-white text-[color:var(--color-ink-1)] font-medium shadow-[0_1px_3px_rgba(0,0,0,0.08)]"
                    : "bg-transparent text-[color:var(--color-ink-1)] font-normal"
                }`}
              >
                {f.label}
                <span className="opacity-50 ml-1.5 tabular-nums">{count}</span>
              </button>
            );
          })}
        </div>
      </div>

      {/* List card */}
      <div className="card-apple max-w-[720px] mx-auto px-7 py-2">
        {filtered.length === 0 ? (
          <div className="py-16 text-center">
            <p className="text-[28px] font-semibold tracking-apple-tight mb-1.5">
              Nothing here.
            </p>
            <p className="text-[15px] text-[color:var(--color-ink-3)] tracking-tight">
              {filter === "completed"
                ? "No completed tasks yet."
                : "Add your first task to get started."}
            </p>
          </div>
        ) : (
          filtered.map((t) => (
            <TaskRow
              key={t.id}
              task={t}
              onOpen={(task) => navigate(`/tasks/${task.id}`)}
            />
          ))
        )}
      </div>

      {/* Fine print */}
      <p className="text-center mt-7 text-apple-caption">
        {tasks.length} task{tasks.length !== 1 && "s"} total · {activeCount} active
      </p>
    </section>
  );
}
