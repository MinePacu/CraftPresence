import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { api, jsonBody } from "../api/client";

type User = { id: string; email: string; displayName: string; role: string };

type AuthState = {
  user: User | null;
  requiresSetup: boolean;
  loading: boolean;
  refresh: () => Promise<void>;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  setup: (input: { displayName: string; email: string; password: string; confirmPassword: string }) => Promise<void>;
};

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [requiresSetup, setRequiresSetup] = useState(false);
  const [loading, setLoading] = useState(true);

  async function refresh() {
    try {
      const setup = await api<{ requiresSetup: boolean }>("/api/setup/status");
      setRequiresSetup(setup.requiresSetup);
      if (!setup.requiresSetup) {
        try {
          const me = await api<{ user: User }>("/api/me");
          setUser(me.user);
        } catch {
          setUser(null);
        }
      }
    } catch {
      setRequiresSetup(false);
      setUser(null);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void refresh();
  }, []);

  const value = useMemo<AuthState>(
    () => ({
      user,
      requiresSetup,
      loading,
      refresh,
      async login(email, password) {
        const result = await api<{ user: User }>("/api/auth/login", { method: "POST", ...jsonBody({ email, password }) });
        setUser(result.user);
        setRequiresSetup(false);
      },
      async logout() {
        await api("/api/auth/logout", { method: "POST" });
        setUser(null);
      },
      async setup(input) {
        const result = await api<{ user: User }>("/api/setup", { method: "POST", ...jsonBody(input) });
        setUser(result.user);
        setRequiresSetup(false);
      }
    }),
    [user, requiresSetup, loading]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const value = useContext(AuthContext);
  if (!value) throw new Error("AuthProvider is missing");
  return value;
}
