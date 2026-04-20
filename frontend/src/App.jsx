import { Routes, Route, useNavigate } from "react-router-dom";
import { AuthProvider, useAuth } from "./auth/AuthContext";
import PrivateRoute from "./auth/PrivateRoute";
import Login from "./auth/Login";
import Signup from "./auth/Signup";
import ConfirmSignup from "./auth/ConfirmSignup";
import TaskList from "./components/TaskList";
import TaskForm from "./components/TaskForm";
import TaskDetail from "./components/TaskDetail";
import { GlobalNav } from "./components/ui";

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

export default function App() {
  return (
    <AuthProvider>
      <div className="min-h-screen bg-[var(--color-bg-light)] flex flex-col">
        <Header />
        <main className="flex-1">
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
        </main>
        <Footer />
      </div>
    </AuthProvider>
  );
}
