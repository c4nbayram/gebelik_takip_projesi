import { createContext, useContext, useEffect, useState } from "react";
import { supabase, supabaseConfigured } from "./supabaseClient.js";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [session, setSession] = useState(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [ready, setReady] = useState(false);
  const [diag, setDiag] = useState(null);

  useEffect(() => {
    if (!supabaseConfigured) {
      setReady(true);
      return;
    }
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session ?? null);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_event, s) => {
      setSession(s ?? null);
    });
    return () => sub.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    let active = true;
    async function check() {
      if (!supabaseConfigured || !session) {
        if (active) {
          setIsAdmin(false);
          setReady(true);
        }
        return;
      }
      let admin = false;
      const dbg = {
        url: import.meta.env.VITE_SUPABASE_URL || "(boş)",
        uid: session.user?.id || "(yok)",
        email: session.user?.email || "(yok)",
        table: "—",
        rpc: "—",
      };
      try {
        const uid = session.user?.id;
        if (uid) {
          const { data, error } = await supabase
            .from("admin_users")
            .select("user_id")
            .eq("user_id", uid)
            .maybeSingle();
          dbg.table = error ? `hata: ${error.message}` : data ? "bulundu ✓" : "satır yok";
          admin = Boolean(data);
        }
        const { data: rpcData, error: rpcErr } = await supabase.rpc("is_admin");
        dbg.rpc = rpcErr ? `hata: ${rpcErr.message}` : String(rpcData);
        if (!admin) admin = rpcData === true;
      } catch (e) {
        dbg.table = `istisna: ${String(e)}`;
      }
      if (active) {
        setDiag(dbg);
        setIsAdmin(admin);
        setReady(true);
      }
    }
    setReady(false);
    check();
    return () => {
      active = false;
    };
  }, [session]);

  async function signIn(email, password) {
    const { error } = await supabase.auth.signInWithPassword({
      email: email.trim(),
      password,
    });
    if (error) throw error;
  }

  async function signOut() {
    if (supabaseConfigured) await supabase.auth.signOut();
    setSession(null);
    setIsAdmin(false);
  }

  return (
    <AuthContext.Provider
      value={{ session, isAdmin, ready, diag, signIn, signOut, configured: supabaseConfigured }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
