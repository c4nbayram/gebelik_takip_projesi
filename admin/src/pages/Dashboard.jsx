import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  CartesianGrid,
} from "recharts";
import { supabase } from "../supabaseClient.js";
import { PageHeader, StatCard, Card, Table, Badge, Spinner } from "../components/ui.jsx";
import { formatMoney, formatDate, planLabel, dayKey } from "../format.js";

const PIE_COLORS = ["#8f78ff", "#ff9fbe", "#5fd3a4", "#f0b968"];
const PLAN_MONTHS = { premium_monthly: 1, premium_quarter: 3, premium_pregnancy: 9 };

export default function Dashboard() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [profiles, setProfiles] = useState([]);
  const [subs, setSubs] = useState([]);
  const [payments, setPayments] = useState([]);
  const [deviceCount, setDeviceCount] = useState(0);
  const [notifCount, setNotifCount] = useState(0);
  const [supportNew, setSupportNew] = useState(0);

  useEffect(() => {
    let active = true;
    async function load() {
      setLoading(true);
      setError("");
      try {
        const [p, s, pay, dev, notif, support] = await Promise.all([
          supabase.from("profiles").select("id,name,email,created_at,caregiver_role,city,baby_name"),
          supabase.from("subscriptions").select("*"),
          supabase.from("payments").select("*").order("created_at", { ascending: false }),
          supabase.from("device_tokens").select("*", { count: "exact", head: true }),
          supabase.from("notifications").select("*", { count: "exact", head: true }),
          supabase.from("support_messages").select("*", { count: "exact", head: true }).eq("status", "new"),
        ]);
        if (!active) return;
        if (p.error) throw p.error;
        setProfiles(p.data || []);
        setSubs(s.data || []);
        setPayments(pay.data || []);
        setDeviceCount(dev.count || 0);
        setNotifCount(notif.count || 0);
        setSupportNew(support.count || 0);
      } catch (e) {
        if (active) setError(e.message || String(e));
      } finally {
        if (active) setLoading(false);
      }
    }
    load();
    return () => {
      active = false;
    };
  }, []);

  const profileMap = useMemo(() => {
    const m = {};
    for (const p of profiles) m[p.id] = p;
    return m;
  }, [profiles]);

  const activeSubs = useMemo(
    () => subs.filter((s) => s.status === "active" && (!s.expires_at || new Date(s.expires_at) > new Date())),
    [subs]
  );

  const premiumSubs = activeSubs.filter((s) => s.plan_code && s.plan_code !== "free");

  const revenue = useMemo(
    () => payments.reduce((sum, p) => sum + Number(p.amount || 0), 0),
    [payments]
  );

  const planDistribution = useMemo(() => {
    const counts = {};
    for (const s of premiumSubs) {
      counts[s.plan_code] = (counts[s.plan_code] || 0) + 1;
    }
    return Object.entries(counts).map(([code, value]) => ({ name: planLabel(code), value }));
  }, [premiumSubs]);

  const mrr = useMemo(
    () =>
      premiumSubs.reduce(
        (s, sub) => s + Number(sub.price || 0) / (PLAN_MONTHS[sub.plan_code] || 1),
        0
      ),
    [premiumSubs]
  );

  const conversion = useMemo(
    () => (profiles.length ? (premiumSubs.length / profiles.length) * 100 : 0),
    [premiumSubs, profiles]
  );

  const signupsByDay = useMemo(() => {
    const map = {};
    const days = [];
    for (let i = 13; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const key = d.toISOString().slice(0, 10);
      map[key] = 0;
      days.push(key);
    }
    for (const pr of profiles) {
      const key = dayKey(pr.created_at);
      if (key in map) map[key] += 1;
    }
    return days.map((key) => ({ day: key.slice(5), kayit: map[key] }));
  }, [profiles]);

  const paymentsByDay = useMemo(() => {
    const map = {};
    const days = [];
    for (let i = 13; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const key = d.toISOString().slice(0, 10);
      map[key] = 0;
      days.push(key);
    }
    for (const p of payments) {
      const key = dayKey(p.created_at);
      if (key in map) map[key] += Number(p.amount || 0);
    }
    return days.map((key) => ({
      day: key.slice(5),
      tutar: Math.round(map[key] * 100) / 100,
    }));
  }, [payments]);

  if (loading) return <Spinner label="Veriler yükleniyor…" />;

  return (
    <>
      <PageHeader
        title="Genel Bakış"
        subtitle="Kullanıcı, üyelik ve gelir özeti"
      />

      {error && <div className="error-box">{error}</div>}

      <div className="grid stat-grid" style={{ marginBottom: 16 }}>
        <StatCard
          label="Kayıtlı kullanıcı"
          value={profiles.length}
          sub="İndirme ≈ kayıt sayısı"
          accent="primary"
          icon="👥"
        />
        <StatCard
          label="Premium üye"
          value={premiumSubs.length}
          sub={`${activeSubs.length} aktif abonelik`}
          accent="accent"
          icon="⭐"
        />
        <StatCard
          label="Toplam satın alma"
          value={payments.length}
          sub="Demo ödeme kayıtları"
          accent="success"
          icon="🧾"
        />
        <StatCard
          label="Toplam gelir"
          value={formatMoney(revenue)}
          sub="Tüm ödemelerin toplamı"
          accent="warning"
          icon="💰"
        />
        <StatCard
          label="Kayıtlı cihaz"
          value={deviceCount}
          sub="Push için kayıtlı token"
          accent="primary"
          icon="📱"
        />
        <StatCard
          label="Gönderilen bildirim"
          value={notifCount}
          sub="Toplam bildirim kaydı"
          accent="accent"
          icon="🔔"
        />
        <StatCard
          label="Açık destek"
          value={supportNew}
          sub="Yanıt bekleyen mesaj"
          accent="warning"
          icon="✉️"
        />
        <StatCard
          label="Tahmini MRR"
          value={formatMoney(mrr)}
          sub="Aylık tekrarlayan gelir"
          accent="success"
          icon="📈"
        />
        <StatCard
          label="Dönüşüm"
          value={`%${conversion.toFixed(1)}`}
          sub="Premium / kullanıcı"
          accent="accent"
          icon="🎯"
        />
      </div>

      <Card title="Yeni kayıtlar (son 14 gün)">
        <div style={{ width: "100%", height: 220 }}>
          <ResponsiveContainer>
            <BarChart data={signupsByDay} margin={{ top: 8, right: 8, left: -10, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#2f2c57" vertical={false} />
              <XAxis dataKey="day" stroke="#8b88be" fontSize={11} />
              <YAxis stroke="#8b88be" fontSize={11} allowDecimals={false} />
              <Tooltip
                contentStyle={{ background: "#1d1b3a", border: "1px solid #2f2c57", borderRadius: 10, color: "#f1f0ff" }}
              />
              <Bar dataKey="kayit" fill="#5fd3a4" radius={[6, 6, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </Card>
      <div style={{ height: 16 }} />

      <div className="cols-2 section-gap" style={{ marginBottom: 16 }}>
        <Card title="Son 14 günün ödeme tutarı">
          <div style={{ width: "100%", height: 260 }}>
            <ResponsiveContainer>
              <BarChart data={paymentsByDay} margin={{ top: 8, right: 8, left: -10, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#2f2c57" vertical={false} />
                <XAxis dataKey="day" stroke="#8b88be" fontSize={11} />
                <YAxis stroke="#8b88be" fontSize={11} />
                <Tooltip
                  contentStyle={{ background: "#1d1b3a", border: "1px solid #2f2c57", borderRadius: 10, color: "#f1f0ff" }}
                  formatter={(v) => formatMoney(v)}
                />
                <Bar dataKey="tutar" fill="#8f78ff" radius={[6, 6, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </Card>

        <Card title="Paket dağılımı">
          {planDistribution.length === 0 ? (
            <p className="muted">Henüz aktif premium abonelik yok.</p>
          ) : (
            <div style={{ width: "100%", height: 260 }}>
              <ResponsiveContainer>
                <PieChart>
                  <Pie
                    data={planDistribution}
                    dataKey="value"
                    nameKey="name"
                    innerRadius={55}
                    outerRadius={90}
                    paddingAngle={3}
                  >
                    {planDistribution.map((entry, i) => (
                      <Cell key={i} fill={PIE_COLORS[i % PIE_COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip
                    contentStyle={{ background: "#1d1b3a", border: "1px solid #2f2c57", borderRadius: 10, color: "#f1f0ff" }}
                  />
                </PieChart>
              </ResponsiveContainer>
              <div className="row gap" style={{ flexWrap: "wrap", justifyContent: "center" }}>
                {planDistribution.map((p, i) => (
                  <span key={p.name} className="row gap" style={{ fontSize: 12.5 }}>
                    <span
                      style={{
                        width: 10,
                        height: 10,
                        borderRadius: 3,
                        background: PIE_COLORS[i % PIE_COLORS.length],
                        display: "inline-block",
                      }}
                    />
                    {p.name} ({p.value})
                  </span>
                ))}
              </div>
            </div>
          )}
        </Card>
      </div>

      <Card title="Son ödemeler">
        <Table
          empty="Henüz ödeme kaydı yok."
          onRowClick={(r) => r.user_id && navigate(`/users/${r.user_id}`)}
          columns={[
            {
              key: "user",
              header: "Kullanıcı",
              render: (r) => profileMap[r.user_id]?.name || profileMap[r.user_id]?.email || "—",
            },
            { key: "plan", header: "Paket", render: (r) => <Badge tone="primary">{planLabel(r.plan_code)}</Badge> },
            { key: "amount", header: "Tutar", render: (r) => formatMoney(r.amount, r.currency) },
            { key: "method", header: "Yöntem", render: (r) => r.method || "—" },
            {
              key: "status",
              header: "Durum",
              render: (r) => <Badge tone={r.status === "paid" ? "success" : "warning"}>{r.status}</Badge>,
            },
            { key: "created_at", header: "Tarih", render: (r) => formatDate(r.created_at, true) },
          ]}
          rows={payments.slice(0, 8)}
        />
      </Card>
    </>
  );
}
