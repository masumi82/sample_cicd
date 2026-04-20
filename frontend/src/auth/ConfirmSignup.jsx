import { useState } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import { useAuth } from "./AuthContext";
import {
  PillButton,
  Field,
  TextInput,
  InlineBanner,
  Spinner,
  HeroShell,
} from "../components/ui";

export default function ConfirmSignup() {
  const location = useLocation();
  const [email, setEmail] = useState(location.state?.email || "");
  const [code, setCode] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const { confirmSignup } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (code.length < 4) {
      setError("Enter the verification code.");
      return;
    }
    setError("");
    setLoading(true);
    try {
      await confirmSignup(email, code);
      navigate("/login", { state: { confirmed: true } });
    } catch (err) {
      setError(err.message || "Confirmation failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <HeroShell
      eyebrow="Step 2 of 2"
      title="Confirm your email."
      subtitle={`We sent a verification code to ${email || "your inbox"}.`}
      footer={
        <button
          type="button"
          onClick={() => navigate("/login")}
          className="text-[color:var(--color-apple-link)] no-underline hover:underline"
        >
          Back to sign in ›
        </button>
      }
    >
      <form onSubmit={handleSubmit} className="flex flex-col gap-[18px]">
        {error && <InlineBanner tone="error">{error}</InlineBanner>}
        <Field label="Email" htmlFor="confirm-email">
          <TextInput
            id="confirm-email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
        </Field>
        <Field label="Verification code" htmlFor="confirm-code" required>
          <TextInput
            id="confirm-code"
            value={code}
            onChange={(e) =>
              setCode(e.target.value.replace(/\D/g, "").slice(0, 6))
            }
            placeholder="123456"
            inputMode="numeric"
            maxLength={6}
            className="text-[22px] text-center tabular-nums tracking-[0.6em]"
          />
        </Field>
        <div className="flex justify-end mt-1">
          <PillButton type="submit" variant="primary" size="md" disabled={loading}>
            {loading ? (
              <>
                <Spinner size={12} color="#fff" /> Verifying…
              </>
            ) : (
              <>Confirm ›</>
            )}
          </PillButton>
        </div>
      </form>
    </HeroShell>
  );
}
