import { lazy, Suspense } from "react";
import { Routes, Route, useNavigate } from "react-router-dom";
import { AuthProvider, useAuth } from "./auth/AuthContext";
import PrivateRoute from "./auth/PrivateRoute";
import { GlobalNav, Spinner } from "./components/ui";

const Login = lazy(() => import("./auth/Login"));
const Signup = lazy(() => import("./auth/Signup"));
const ConfirmSignup = lazy(() => import("./auth/ConfirmSignup"));
const TaskList = lazy(() => import("./components/TaskList"));
const TaskForm = lazy(() => import("./components/TaskForm"));
const TaskDetail = lazy(() => import("./components/TaskDetail"));

function Header() {
  const { user, logout, authEnabled } = useAuth();
  const navigate = useNavigate();

  return (
    <GlobalNav
      user={user}
      authEnabled={authEnabled}
      onHome={() => navigate("/")}
      onLogout={logout}
    />
  );
}

function Footer() {
  return (
    <footer className="mt-20 border-t border-[var(--color-border-ap)] bg-[var(--color-bg-gray)] px-[22px] py-6">
      <div className="mx-auto max-w-[980px] text-[12px] leading-[1.5] tracking-tight text-[color:var(--color-ink-2)] flex flex-wrap justify-between gap-2">
        <span>Task Manager · sample_cicd</span>
        <span>CI/CD learning project</span>
      </div>
    </footer>
  );
}

function RouteFallback() {
  return (
    <div className="flex items-center justify-center py-24">
      <Spinner size={28} color="var(--color-apple-blue)" />
    </div>
  );
}

export default function App() {
  return (
    <AuthProvider>
      <div className="min-h-screen bg-[var(--color-bg-light)] flex flex-col">
        <Header />
        <main className="flex-1">
          <Suspense fallback={<RouteFallback />}>
            <Routes>
              <Route path="/login" element={<Login />} />
              <Route path="/signup" element={<Signup />} />
              <Route path="/confirm" element={<ConfirmSignup />} />
              <Route
                path="/"
                element={
                  <PrivateRoute>
                    <TaskList />
                  </PrivateRoute>
                }
              />
              <Route
                path="/tasks/new"
                element={
                  <PrivateRoute>
                    <TaskForm />
                  </PrivateRoute>
                }
              />
              <Route
                path="/tasks/:id"
                element={
                  <PrivateRoute>
                    <TaskDetail />
                  </PrivateRoute>
                }
              />
            </Routes>
          </Suspense>
        </main>
        <Footer />
      </div>
    </AuthProvider>
  );
}
