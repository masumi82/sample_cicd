import { createContext, useContext, useState, useEffect, useCallback } from "react";
import {
  getCurrentUser,
  getIdToken,
  signIn as cognitoSignIn,
  signUp as cognitoSignUp,
  confirmSignUp as cognitoConfirmSignUp,
  signOut as cognitoSignOut,
  getUserPool,
} from "./cognito";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const authEnabled = !!getUserPool();

  useEffect(() => {
    if (!authEnabled) {
      setLoading(false);
      return;
    }
    const cognitoUser = getCurrentUser();
    if (cognitoUser) {
      cognitoUser.getSession((err, session) => {
        if (!err && session && session.isValid()) {
          setUser({ email: cognitoUser.getUsername() });
        }
        setLoading(false);
      });
    } else {
      setLoading(false);
    }
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

  const logout = useCallback(() => {
    cognitoSignOut();
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
