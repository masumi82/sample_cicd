import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "./AuthContext";
import {
  PillButton,
  Field,
  TextInput,
  InlineBanner,
  Spinner,
  HeroShell,
} from "../components/ui";

export default function Signup() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const { signup } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    if (password !== confirmPassword) {
      setError("Passwords do not match.");
      return;
    }
    if (password.length < 8) {
      setError("Password must be at least 8 characters.");
      return;
    }
    setLoading(true);
    try {
      await signup(email, password);
      navigate("/confirm", { state: { email } });
    } catch (err) {
      setError(err.message || "Sign up failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <HeroShell
      eyebrow="Task Manager"
      title="Create your account."
      subtitle="One place for everything you want to finish."
      footer={
        <>
          Already have an account?{" "}
          <Link
            to="/login"
            className="text-[color:var(--color-apple-link)] no-underline hover:underline"
          >
            Sign in ›
          </Link>
        </>
      }
    >
      <form onSubmit={handleSubmit} className="flex flex-col gap-[18px]">
        {error && <InlineBanner tone="error">{error}</InlineBanner>}
        <Field label="Email" htmlFor="signup-email" required>
          <TextInput
            id="signup-email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="you@example.com"
            required
          />
        </Field>
        <Field
          label="Password"
          htmlFor="signup-password"
          hint="Min 8 chars · uppercase · lowercase · number · symbol"
          required
        >
          <TextInput
            id="signup-password"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            minLength={8}
            required
          />
        </Field>
        <Field label="Confirm password" htmlFor="signup-confirm" required>
          <TextInput
            id="signup-confirm"
            type="password"
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            required
          />
        </Field>
        <div className="flex justify-end mt-1">
          <PillButton type="submit" variant="primary" size="md" disabled={loading}>
            {loading ? (
              <>
                <Spinner size={12} color="#fff" /> Creating…
              </>
            ) : (
              <>Continue ›</>
            )}
          </PillButton>
        </div>
      </form>
    </HeroShell>
  );
}
