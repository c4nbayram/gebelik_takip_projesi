import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "../supabaseClient.js";
import { PageHeader, Card, Table, Badge, Spinner } from "../components/ui.jsx";
import { formatMoney, formatDate, planLabel } from "../format.js";

export default function Subscriptions() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [rows, setRows] = useState([]);
  const [profileMap, setProfileMap] = useState({});

  useEffect(() => {
    let active = true;
    async function load() {
      setLoading(true);
      try {
        const [s, p] = await Promise.all([
          supabase.from("subscriptions").select("*").order("started_at", { ascending: false }),
          supabase.from("profiles").select("id,name,email"),
        ]);
        if (!active) return;
        if (s.error) throw s.error;
        const map = {};
        for (const pr of p.data || []) map[pr.id] = pr;
        setProfileMap(map);
        setRows(s.data || []);
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

  const activeCount = useMemo(
    () => rows.filter((r) => r.status === "active" && (!r.expires_at || new Date(r.expires_at) > new Date())).length,
    [rows]
  );

  if (loading) return <Spinner />;

  function statusBadge(r) {
    const expired = r.expires_at && new Date(r.expires_at) <= new Date();
    if (r.status !== "active") return <Badge tone="neutral">{r.status}</Badge>;
    if (expired) return <Badge tone="warning">süresi doldu</Badge>;
    return <Badge tone="success">aktif</Badge>;
  }

  return (
    <>
      <PageHeader title="Abonelikler" subtitle={`${rows.length} kayıt · ${activeCount} aktif`} />
      {error && <div className="error-box">{error}</div>}
      <Card>
        <Table
          empty="Abonelik kaydı yok."
          onRowClick={(r) => r.user_id && navigate(`/users/${r.user_id}`)}
          columns={[
            {
              key: "user",
              header: "Kullanıcı",
              render: (r) => profileMap[r.user_id]?.name || profileMap[r.user_id]?.email || "—",
            },
            { key: "plan", header: "Paket", render: (r) => <Badge tone="primary">{planLabel(r.plan_code)}</Badge> },
            { key: "price", header: "Ücret", render: (r) => formatMoney(r.price, r.currency) },
            { key: "status", header: "Durum", render: statusBadge },
            { key: "started_at", header: "Başlangıç", render: (r) => formatDate(r.started_at, true) },
            { key: "expires_at", header: "Bitiş", render: (r) => (r.expires_at ? formatDate(r.expires_at) : "Ömür boyu") },
          ]}
          rows={rows}
        />
      </Card>
    </>
  );
}
