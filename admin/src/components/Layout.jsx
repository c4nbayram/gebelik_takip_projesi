import { NavLink, Outlet, useNavigate } from "react-router-dom";
import { useAuth } from "../auth.jsx";

const NAV = [
  { to: "/", label: "Genel Bakış", icon: "📊", end: true },
  { to: "/users", label: "Kullanıcılar", icon: "👥" },
  { to: "/risk", label: "Risk Gözetimi", icon: "🔴" },
  { to: "/subscriptions", label: "Abonelikler", icon: "⭐" },
  { to: "/payments", label: "Ödemeler", icon: "💳" },
  { to: "/notifications", label: "Bildirimler", icon: "🔔" },
  { to: "/content", label: "İçerik Yönetimi", icon: "🗂️" },
  { to: "/support", label: "Destek", icon: "✉️" },
  { to: "/requests", label: "Talepler (KVKK)", icon: "📨" },
];

export default function Layout() {
  const { session, signOut } = useAuth();
  const navigate = useNavigate();

  async function handleLogout() {
    await signOut();
    navigate("/login", { replace: true });
  }

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-logo">🤰</div>
          <div>
            <div className="brand-title">Gebelik Takip</div>
            <div className="brand-sub">Yönetim Paneli</div>
          </div>
        </div>
        <nav>
          {NAV.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              className={({ isActive }) => (isActive ? "nav-item active" : "nav-item")}
            >
              <span className="nav-icon">{item.icon}</span>
              {item.label}
            </NavLink>
          ))}
        </nav>
        <div className="sidebar-foot">
          <div className="muted small">Giriş yapan</div>
          <div className="email" title={session?.user?.email}>
            {session?.user?.email}
          </div>
          <button className="btn btn-ghost full" onClick={handleLogout}>
            Çıkış Yap
          </button>
        </div>
      </aside>
      <main className="content">
        <Outlet />
      </main>
    </div>
  );
}
