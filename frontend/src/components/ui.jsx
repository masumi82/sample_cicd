/**
 * Apple design system primitives for the v14 Claude Design refactor.
 * Tailwind-first — inline styles only for values without Tailwind equivalents
 * (e.g. 980px pill radius, apple-specific focus rings).
 */

const VARIANT_CLASSES = {
  primary:
    "bg-[var(--color-apple-blue)] text-white border border-[var(--color-apple-blue)] hover:bg-[var(--color-apple-blue-hover)]",
  secondary:
    "bg-transparent text-[var(--color-apple-blue)] border border-[var(--color-apple-blue)] hover:bg-[rgba(0,113,227,0.06)]",
  dark:
    "bg-[var(--color-ink-1)] text-white border border-[var(--color-ink-1)] hover:bg-[#2d2d2f]",
  ghost:
    "bg-transparent text-[var(--color-ink-1)] border border-[var(--color-border-ap)] hover:bg-[var(--color-bg-gray)]",
  danger:
    "bg-transparent text-[var(--color-apple-red-strong)] border border-[rgba(215,0,21,0.35)] hover:bg-[rgba(255,59,48,0.08)]",
  "danger-solid":
    "bg-[var(--color-apple-red-strong)] text-white border border-[var(--color-apple-red-strong)] hover:bg-[#b8000e]",
  success:
    "bg-[var(--color-apple-green)] text-white border border-[var(--color-apple-green)] hover:bg-[var(--color-apple-green-hover)]",
};

const SIZE_CLASSES = {
  sm: "px-3.5 py-1.5 text-xs",
  md: "px-5 py-2.5 text-sm",
  lg: "px-6 py-3 text-base",
};

export function PillButton({
  children,
  variant = "primary",
  size = "md",
  type = "button",
  onClick,
  disabled = false,
  className = "",
  ...rest
}) {
  const base =
    "inline-flex items-center gap-1.5 font-normal pill tracking-apple leading-tight whitespace-nowrap transition-colors duration-200 ease-[var(--ease-apple)] disabled:opacity-40 disabled:cursor-not-allowed";
  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled}
      className={`${base} ${VARIANT_CLASSES[variant]} ${SIZE_CLASSES[size]} ${className}`}
      {...rest}
    >
      {children}
    </button>
  );
}

export function ChevronLink({ children, onClick, href = "#", className = "" }) {
  return (
    <a
      href={href}
      onClick={(e) => {
        if (onClick) {
          e.preventDefault();
          onClick();
        }
      }}
      className={`text-[color:var(--color-apple-link)] no-underline text-sm tracking-apple hover:underline ${className}`}
    >
      {children}
      <span className="inline-block ml-0.5 -translate-y-px">›</span>
    </a>
  );
}

export function Field({ label, htmlFor, hint, error, required, children }) {
  return (
    <div className="flex flex-col gap-1.5">
      <label
        htmlFor={htmlFor}
        className="text-xs font-normal text-[color:var(--color-ink-2)] tracking-tight"
      >
        {label}
        {required && (
          <span className="ml-0.5 text-[color:var(--color-apple-red-strong)]">*</span>
        )}
      </label>
      {children}
      {hint && !error && (
        <p className="text-[11px] text-[color:var(--color-ink-3)]">{hint}</p>
      )}
      {error && (
        <p className="text-[11px] text-[color:var(--color-apple-red-strong)]">{error}</p>
      )}
    </div>
  );
}

const INPUT_BASE =
  "w-full rounded-[12px] border border-[var(--color-border-ap)] bg-white px-4 py-3.5 text-[17px] text-[color:var(--color-ink-1)] tracking-apple outline-none transition-[border-color,box-shadow] duration-200 ease-[var(--ease-apple)] focus:border-[var(--color-apple-blue)] focus:shadow-[0_0_0_4px_rgba(0,113,227,0.15)] placeholder:text-[color:var(--color-ink-3)]";

export function TextInput({ className = "", ...props }) {
  return <input {...props} className={`${INPUT_BASE} ${className}`} />;
}

export function TextArea({ className = "", rows = 5, ...props }) {
  return (
    <textarea
      rows={rows}
      {...props}
      className={`${INPUT_BASE} resize-y min-h-[120px] leading-relaxed ${className}`}
    />
  );
}

const TONE_CLASSES = {
  error:
    "bg-[rgba(255,59,48,0.08)] text-[#b8000e] border-[rgba(255,59,48,0.25)]",
  info:
    "bg-[rgba(0,113,227,0.07)] text-[#0053a8] border-[rgba(0,113,227,0.22)]",
  success:
    "bg-[rgba(52,199,89,0.09)] text-[#1f7a3a] border-[rgba(52,199,89,0.3)]",
};

export function InlineBanner({ tone = "error", children }) {
  return (
    <div
      className={`border rounded-[12px] px-4 py-3 text-sm tracking-tight leading-snug ${TONE_CLASSES[tone]}`}
      role={tone === "error" ? "alert" : "status"}
    >
      {children}
    </div>
  );
}

export function Spinner({ size = 18, color = "#86868b" }) {
  return (
    <span
      className="inline-block rounded-full animate-[appleSpin_800ms_linear_infinite]"
      style={{
        width: size,
        height: size,
        border: `2px solid ${color}33`,
        borderTopColor: color,
      }}
      aria-hidden="true"
    />
  );
}

export function StatusDisc({ completed, onClick, size = 22 }) {
  const interactive = Boolean(onClick);
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={completed ? "Mark as active" : "Mark as completed"}
      className="inline-flex items-center justify-center rounded-full p-0 transition-[background-color,border-color] duration-200 ease-[var(--ease-apple)] shrink-0"
      style={{
        width: size,
        height: size,
        border: completed ? "none" : "1.5px solid var(--color-border-ap)",
        background: completed ? "var(--color-apple-green)" : "transparent",
        cursor: interactive ? "pointer" : "default",
      }}
    >
      {completed && (
        <svg
          width={size * 0.55}
          height={size * 0.55}
          viewBox="0 0 24 24"
          fill="none"
          stroke="#fff"
          strokeWidth="3.5"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <path d="M4.5 12.75l6 6 9-13.5" />
        </svg>
      )}
    </button>
  );
}

export function Toast({ message }) {
  if (!message) return null;
  return (
    <div
      role="status"
      className="fixed bottom-8 left-1/2 -translate-x-1/2 bg-[var(--color-ink-1)] text-white pill px-6 py-3 text-sm tracking-apple z-[100] pointer-events-none shadow-[0_10px_40px_rgba(0,0,0,0.25)] animate-[toastIn_300ms_cubic-bezier(0.16,1,0.3,1)]"
    >
      {message}
    </div>
  );
}

/**
 * Apple-style sticky global nav.
 * Shows only real routes (Tasks) + user/sign-out. App name replaces the Apple glyph.
 */
export function GlobalNav({ appName = "Task Manager", user, authEnabled, onLogout, onHome }) {
  return (
    <nav className="sticky top-0 z-50 h-11 nav-blur bg-white/72 border-b border-black/8">
      <div className="mx-auto max-w-[980px] h-full flex items-center justify-between px-[22px] text-xs tracking-tight">
        <button
          type="button"
          onClick={onHome}
          className="flex items-center gap-2 text-[color:var(--color-ink-1)] font-medium text-[13px] tracking-apple"
        >
          <svg
            width="18"
            height="18"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.8"
            strokeLinecap="round"
            strokeLinejoin="round"
            aria-hidden="true"
          >
            <path d="M9 11l3 3L22 4" />
            <path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11" />
          </svg>
          {appName}
        </button>

        <div className="flex items-center gap-6">
          <button
            type="button"
            onClick={onHome}
            className="text-[color:var(--color-ink-1)] opacity-90 hover:opacity-100"
          >
            Tasks
          </button>

          {authEnabled && user && (
            <>
              <span className="opacity-70 hidden sm:inline">{user.email}</span>
              <button
                type="button"
                onClick={onLogout}
                className="text-[color:var(--color-apple-link)] hover:underline"
              >
                Sign out
              </button>
            </>
          )}
        </div>
      </div>
    </nav>
  );
}

/**
 * Centered hero shell used by auth screens and forms.
 */
export function HeroShell({ eyebrow, title, subtitle, children, maxWidth = 480, footer }) {
  return (
    <section
      className="mx-auto px-[22px] pt-20 pb-28 animate-[fadeInUp_420ms_cubic-bezier(0.16,1,0.3,1)]"
      style={{ maxWidth }}
    >
      <div className="text-center mb-10">
        {eyebrow && (
          <p className="text-[17px] text-[color:var(--color-ink-1)] tracking-apple mb-2">
            {eyebrow}
          </p>
        )}
        <h1 className="text-apple-h1 m-0 mb-3">{title}</h1>
        {subtitle && <p className="text-apple-intro m-0">{subtitle}</p>}
      </div>
      <div className="card-apple px-9 py-9">{children}</div>
      {footer && (
        <div className="text-center mt-7 text-sm text-[color:var(--color-ink-2)]">{footer}</div>
      )}
    </section>
  );
}
