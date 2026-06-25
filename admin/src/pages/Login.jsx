import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../auth.jsx";

function translateError(err) {
  const msg = (err && err.message) || String(err);
  if (/invalid login credentials/i.test(msg)) return "E-posta veya şifre hatalı.";
  if (/email not confirmed/i.test(msg)) return "E-posta doğrulanmamış.";
  return msg;
}

export default function Login() {
  const { signIn, signOut, session, isAdmin, ready, configured, diag } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState("admin@gebelik.app");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (ready && session && isAdmin) {
      navigate("/", { replace: true });
    }
  }, [ready, session, isAdmin]);

  async function handleSubmit(e) {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      await signIn(email, password);
    } catch (err) {
      setError(translateError(err));
    } finally {
      setBusy(false);
    }
  }

  const blocked = ready && session && !isAdmin;

  if (blocked) {
    return (
      <div className="login-wrap">
        <div className="login-card">
          <div className="login-logo">🔒</div>
          <h1>Yetki bulunamadı</h1>
          <p className="sub muted">Bu oturum yönetici olarak tanınmadı.</p>

          <div className="hint" style={{ textAlign: "left" }}>
            <strong>Teşhis</strong>
            <div style={{ marginTop: 8, lineHeight: 1.8, wordBreak: "break-all" }}>
              Proje URL: <code>{diag?.url}</code>
              <br />
              Giriş e-postası: <code>{diag?.email}</code>
              <br />
              Oturum uid: <code>{diag?.uid}</code>
              <br />
              admin_users okuması: <code>{diag?.table}</code>
              <br />
              is_admin(): <code>{diag?.rpc}</code>
            </div>
            <div style={{ marginTop: 10 }}>
              <strong>uid</strong>, SQL'deki <code>admin_users</code> satırının uid'siyle aynı
              olmalı ve <strong>Proje URL</strong>, SQL'i çalıştırdığın projeyle aynı olmalı.
            </div>
          </div>

          <button
            className="btn btn-primary full"
            style={{ marginTop: 14 }}
            onClick={async () => {
              await signOut();
            }}
          >
            Farklı hesapla gir
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="login-wrap">
      <form className="login-card" onSubmit={handleSubmit}>
        <div className="login-logo">🤰</div>
        <h1>Yönetim Paneli</h1>
        <p className="sub muted">Gebelik Takip · yönetici girişi</p>

        {!configured && (
          <div className="error-box">
            Supabase yapılandırması eksik. <code>admin/.env</code> dosyasını oluşturun.
          </div>
        )}
        {error && <div className="error-box">{error}</div>}

        <div className="field">
          <label>E-posta</label>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            autoComplete="username"
            required
          />
        </div>
        <div className="field">
          <label>Şifre</label>
          <div className="password-input-wrap">
            <input
              type={showPassword ? "text" : "password"}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
              required
            />
            <button
              className="password-toggle"
              type="button"
              onClick={() => setShowPassword((visible) => !visible)}
              aria-label={showPassword ? "Şifreyi gizle" : "Şifreyi göster"}
              aria-pressed={showPassword}
              title={showPassword ? "Şifreyi gizle" : "Şifreyi göster"}
            >
              {showPassword ? (
                <svg viewBox="0 0 24 24" aria-hidden="true">
                  <path d="M3 3l18 18M10.6 10.7a2 2 0 002.7 2.7M9.9 4.2A10.7 10.7 0 0112 4c5.5 0 9 5.5 9 5.5a16 16 0 01-2.1 2.6M6.2 6.2C4.1 7.6 3 9.5 3 9.5S6.5 15 12 15c1.2 0 2.3-.3 3.3-.7" />
                </svg>
              ) : (
                <svg viewBox="0 0 24 24" aria-hidden="true">
                  <path d="M3 12s3.5-5.5 9-5.5S21 12 21 12s-3.5 5.5-9 5.5S3 12 3 12z" />
                  <circle cx="12" cy="12" r="2.5" />
                </svg>
              )}
            </button>
          </div>
        </div>

        <button className="btn btn-primary full" type="submit" disabled={busy || !configured}>
          {busy ? "Giriş yapılıyor…" : "Giriş Yap"}
        </button>

        <div className="hint">
          <strong>Demo yönetici hesabı</strong>
          <br />
          E-posta: <code>admin@gebelik.app</code>
          <br />
          Şifre: <code>Admin1234!</code>
        </div>
      </form>
    </div>
  );
}
