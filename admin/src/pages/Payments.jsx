import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "../supabaseClient.js";
import { PageHeader, Card, Table, Badge, Spinner, StatCard } from "../components/ui.jsx";
import { formatMoney, formatDate, planLabel } from "../format.js";

export default function Payments() {
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
        const [pay, p] = await Promise.all([
          supabase.from("payments").select("*").order("created_at", { ascending: false }),
          supabase.from("profiles").select("id,name,email"),
        ]);
        if (!active) return;
        if (pay.error) throw pay.error;
        const map = {};
        for (const pr of p.data || []) map[pr.id] = pr;
        setProfileMap(map);
        setRows(pay.data || []);
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

  const revenue = useMemo(() => rows.reduce((s, r) => s + Number(r.amount || 0), 0), [rows]);

  if (loading) return <Spinner />;

  return (
    <>
      <PageHeader title="Ödemeler" subtitle="Tüm satın alma kayıtları (demo)" />
      {error && <div className="error-box">{error}</div>}

      <div className="grid stat-grid" style={{ marginBottom: 16 }}>
        <StatCard label="Toplam satın alma" value={rows.length} accent="success" icon="🧾" />
        <StatCard label="Toplam gelir" value={formatMoney(revenue)} accent="warning" icon="💰" />
      </div>

      <Card>
        <Table
          empty="Ödeme kaydı yok."
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
          rows={rows}
        />
      </Card>
    </>
  );
}
