import { useState } from "react";
import { Link, useNavigate, useLocation } from "react-router-dom";
import { useAuth } from "./AuthContext";
import {
  PillButton,
  Field,
  TextInput,
  InlineBanner,
  Spinner,
  HeroShell,
} from "../components/ui";

export default function Login() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  const from = location.state?.from?.pathname || "/";

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    if (!email || !password) {
      setError("Enter your email and password.");
      return;
    }
    setLoading(true);
    try {
      await login(email, password);
      navigate(from, { replace: true });
    } catch (err) {
      setError(err.message || "Login failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <HeroShell
      eyebrow="Task Manager"
      title="Sign in."
      subtitle="Pick up right where you left off."
      footer={
        <>
          New here?{" "}
          <Link
            to="/signup"
            className="text-[color:var(--color-apple-link)] no-underline hover:underline"
          >
            Create your account ›
          </Link>
        </>
      }
    >
      <form onSubmit={handleSubmit} className="flex flex-col gap-[18px]">
        {error && <InlineBanner tone="error">{error}</InlineBanner>}
        <Field label="Email" htmlFor="login-email" required>
          <TextInput
            id="login-email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="you@example.com"
            autoComplete="email"
            required
          />
        </Field>
        <Field label="Password" htmlFor="login-password" required>
          <TextInput
            id="login-password"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            required
          />
        </Field>
        <div className="flex items-center justify-end mt-1">
          <PillButton type="submit" variant="primary" size="md" disabled={loading}>
            {loading ? (
              <>
                <Spinner size={12} color="#fff" /> Signing in…
              </>
            ) : (
              <>Sign in ›</>
            )}
          </PillButton>
        </div>
      </form>
    </HeroShell>
  );
}
