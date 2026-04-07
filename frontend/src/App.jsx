import { Routes, Route, Link } from "react-router-dom";
import { AuthProvider, useAuth } from "./auth/AuthContext";
import PrivateRoute from "./auth/PrivateRoute";
import Login from "./auth/Login";
import Signup from "./auth/Signup";
import ConfirmSignup from "./auth/ConfirmSignup";
import TaskList from "./components/TaskList";
import TaskForm from "./components/TaskForm";
import TaskDetail from "./components/TaskDetail";

function Header() {
  const { user, logout, authEnabled } = useAuth();

  return (
    <header className="sticky top-0 z-10 border-b border-zinc-200 bg-white/80 backdrop-blur-md">
      <div className="mx-auto flex max-w-3xl items-center justify-between px-4 py-4 sm:px-6">
        <Link to="/" className="text-xl font-bold tracking-tight text-zinc-900 hover:text-primary transition-colors">
          Task Manager
        </Link>
        <div className="flex items-center gap-3">
          <span className="rounded-full bg-zinc-100 px-3 py-1 text-xs font-medium text-zinc-500">
            sample_cicd v7
          </span>
          {authEnabled && user && (
            <>
              <span className="text-xs text-zinc-500">{user.email}</span>
              <button
                onClick={logout}
                className="rounded-lg border border-zinc-300 px-3 py-1 text-xs font-medium text-zinc-600 hover:bg-zinc-50 transition-colors"
              >
                Logout
              </button>
            </>
          )}
        </div>
      </div>
    </header>
  );
}

export default function App() {
  return (
    <AuthProvider>
      <div className="min-h-screen bg-zinc-50">
        <Header />
        <main className="mx-auto max-w-3xl px-4 py-8 sm:px-6">
          <Routes>
            <Route path="/login" element={<Login />} />
            <Route path="/signup" element={<Signup />} />
            <Route path="/confirm" element={<ConfirmSignup />} />
            <Route path="/" element={<PrivateRoute><TaskList /></PrivateRoute>} />
            <Route path="/tasks/new" element={<PrivateRoute><TaskForm /></PrivateRoute>} />
            <Route path="/tasks/:id" element={<PrivateRoute><TaskDetail /></PrivateRoute>} />
          </Routes>
        </main>
      </div>
    </AuthProvider>
  );
}
