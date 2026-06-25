import { Routes, Route, Navigate, useNavigate } from "react-router-dom";
import { useAuth } from "./auth.jsx";
import Layout from "./components/Layout.jsx";
import { Spinner } from "./components/ui.jsx";
import Login from "./pages/Login.jsx";
import Dashboard from "./pages/Dashboard.jsx";
import Users from "./pages/Users.jsx";
import UserDetail from "./pages/UserDetail.jsx";
import Subscriptions from "./pages/Subscriptions.jsx";
import Payments from "./pages/Payments.jsx";
import Notifications from "./pages/Notifications.jsx";
import Support from "./pages/Support.jsx";
import Risk from "./pages/Risk.jsx";
import Requests from "./pages/Requests.jsx";
import Content from "./pages/Content.jsx";

function ConfigError() {
  return (
    <div className="center fullscreen">
      <div className="card" style={{ maxWidth: 520 }}>
        <div className="card-body">
          <h2>Yapılandırma eksik</h2>
          <p className="muted">
            <code>admin/.env</code> dosyasını oluşturup <code>VITE_SUPABASE_URL</code> ve{" "}
            <code>VITE_SUPABASE_ANON_KEY</code> değerlerini girin (örnek için{" "}
            <code>.env.example</code>). Ardından <code>npm run dev</code> komutunu yeniden
            çalıştırın.
          </p>
        </div>
      </div>
    </div>
  );
}

function NotAuthorized() {
  const { signOut } = useAuth();
  const navigate = useNavigate();
  return (
    <div className="center fullscreen">
      <div className="card" style={{ maxWidth: 480 }}>
        <div className="card-body">
          <h2>Yetkiniz yok</h2>
          <p className="muted">
            Bu hesap yönetici değil. Yönetici hesabıyla giriş yapın.
          </p>
          <button
            className="btn btn-primary"
            onClick={async () => {
              await signOut();
              navigate("/login", { replace: true });
            }}
          >
            Çıkış yap
          </button>
        </div>
      </div>
    </div>
  );
}

function Protected({ children }) {
  const { ready, session, isAdmin, configured } = useAuth();
  if (!configured) return <ConfigError />;
  if (!ready) return <Spinner label="Oturum kontrol ediliyor…" />;
  if (!session) return <Navigate to="/login" replace />;
  if (!isAdmin) return <NotAuthorized />;
  return children;
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route
        element={
          <Protected>
            <Layout />
          </Protected>
        }
      >
        <Route index element={<Dashboard />} />
        <Route path="users" element={<Users />} />
        <Route path="users/:id" element={<UserDetail />} />
        <Route path="risk" element={<Risk />} />
        <Route path="requests" element={<Requests />} />
        <Route path="subscriptions" element={<Subscriptions />} />
        <Route path="payments" element={<Payments />} />
        <Route path="notifications" element={<Notifications />} />
        <Route path="content" element={<Content />} />
        <Route path="support" element={<Support />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
