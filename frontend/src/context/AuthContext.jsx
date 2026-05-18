import { createContext, useContext, useState, useCallback, useMemo } from 'react';
import { api, setAuthToken } from '../api/client.js';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [session, setSession] = useState(null);

  const applySession = useCallback((auth) => {
    setAuthToken(auth.token);
    setSession({ username: auth.username, role: auth.role });
  }, []);

  const login = useCallback(
    async (credentials) => {
      const auth = await api.login(credentials);
      applySession(auth);
    },
    [applySession]
  );

  const register = useCallback(
    async (payload) => {
      const auth = await api.register(payload);
      applySession(auth);
    },
    [applySession]
  );

  const logout = useCallback(() => {
    setAuthToken(null);
    setSession(null);
  }, []);

  const value = useMemo(
    () => ({ session, isAuthenticated: !!session, login, register, logout }),
    [session, login, register, logout]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return ctx;
}
