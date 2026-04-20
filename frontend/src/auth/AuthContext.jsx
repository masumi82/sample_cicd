import { createContext, useContext, useState, useEffect, useCallback } from "react";
import {
  getCurrentUser,
  getIdToken,
  signIn as cognitoSignIn,
  signUp as cognitoSignUp,
  confirmSignUp as cognitoConfirmSignUp,
  signOut as cognitoSignOut,
  isAuthConfigured,
} from "./cognito";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const authEnabled = isAuthConfigured();

  useEffect(() => {
    if (!authEnabled) {
      setLoading(false);
      return;
    }
    let cancelled = false;
    (async () => {
      const cognitoUser = await getCurrentUser();
      if (cancelled) return;
      if (cognitoUser) {
        cognitoUser.getSession((err, session) => {
          if (cancelled) return;
          if (!err && session && session.isValid()) {
            setUser({ email: cognitoUser.getUsername() });
          }
          setLoading(false);
        });
      } else {
        setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [authEnabled]);

  const login = useCallback(async (email, password) => {
    await cognitoSignIn(email, password);
    setUser({ email });
  }, []);

  const signup = useCallback(async (email, password) => {
    await cognitoSignUp(email, password);
  }, []);

  const confirmSignup = useCallback(async (email, code) => {
    await cognitoConfirmSignUp(email, code);
  }, []);

  const logout = useCallback(async () => {
    await cognitoSignOut();
    setUser(null);
  }, []);

  const value = {
    user,
    loading,
    authEnabled,
    login,
    signup,
    confirmSignup,
    logout,
    getToken: getIdToken,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
