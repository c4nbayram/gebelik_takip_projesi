import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "../supabaseClient.js";
import { PageHeader, Card, Table, Badge, Spinner, StatCard } from "../components/ui.jsx";
import { formatDate } from "../format.js";

const HIGH = /yuksek|yüksek|high/i;
const MID = /mid|orta/i;

export default function Risk() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [entries, setEntries] = useState([]);
  const [profileMap, setProfileMap] = useState({});

  useEffect(() => {
    let active = true;
    async function load() {
      setLoading(true);
      try {
        const [we, p] = await Promise.all([
          supabase
            .from("week_entries")
            .select("user_id,week_no,risk_label,risk_score,updated_at,created_at"),
          supabase.from("profiles").select("id,name,email,city,baby_name"),
        ]);
        if (!active) return;
        if (we.error) throw we.error;
        const map = {};
        for (const pr of p.data || []) map[pr.id] = pr;
        setProfileMap(map);
        setEntries(we.data || []);
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

  const latestByUser = useMemo(() => {
    const latest = {};
    for (const e of entries) {
      const t = new Date(e.updated_at || e.created_at).getTime();
      if (!latest[e.user_id] || t > latest[e.user_id]._t) {
        latest[e.user_id] = { ...e, _t: t };
      }
    }
    return Object.values(latest);
  }, [entries]);

  const high = useMemo(
    () => latestByUser.filter((e) => HIGH.test(e.risk_label || "")),
    [latestByUser]
  );
  const mid = useMemo(
    () => latestByUser.filter((e) => MID.test(e.risk_label || "")),
    [latestByUser]
  );

  if (loading) return <Spinner />;

  function riskBadge(label) {
    if (HIGH.test(label || "")) return <Badge tone="danger">{label}</Badge>;
    if (MID.test(label || "")) return <Badge tone="warning">{label}</Badge>;
    return <Badge tone="success">{label || "—"}</Badge>;
  }

  const rows = [...high, ...mid];

  return (
    <>
      <PageHeader
        title="Risk Gözetimi"
        subtitle="Son analizine göre dikkat gerektiren kullanıcılar"
      />
      {error && <div className="error-box">{error}</div>}

      <div className="grid stat-grid" style={{ marginBottom: 16 }}>
        <StatCard label="Yüksek riskli" value={high.length} accent="warning" icon="🔴" />
        <StatCard label="Orta riskli" value={mid.length} accent="primary" icon="🟠" />
        <StatCard label="Takipteki kullanıcı" value={latestByUser.length} accent="success" icon="👥" />
      </div>

      <Card title="Yüksek ve orta riskli kullanıcılar (son ölçüm)">
        <Table
          empty="Şu an dikkat gerektiren kullanıcı yok."
          onRowClick={(r) => r.user_id && navigate(`/users/${r.user_id}`)}
          columns={[
            {
              key: "user",
              header: "Kullanıcı",
              render: (r) => profileMap[r.user_id]?.name || profileMap[r.user_id]?.email || "—",
            },
            { key: "email", header: "E-posta", render: (r) => profileMap[r.user_id]?.email || "—" },
            { key: "city", header: "Şehir", render: (r) => profileMap[r.user_id]?.city || "—" },
            { key: "week", header: "Hafta", render: (r) => (r.week_no ?? "—") + ". hafta" },
            { key: "risk", header: "Risk", render: (r) => riskBadge(r.risk_label) },
            {
              key: "score",
              header: "Skor",
              render: (r) => `${Math.round((r.risk_score || 0) * 100)}%`,
            },
            { key: "updated", header: "Son ölçüm", render: (r) => formatDate(r.updated_at || r.created_at, true) },
          ]}
          rows={rows}
        />
      </Card>
    </>
  );
}
