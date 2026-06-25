import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "../supabaseClient.js";
import { PageHeader, Card, Table, Badge, Spinner, StatCard } from "../components/ui.jsx";
import { formatDate } from "../format.js";

function typeBadge(type) {
  if (type === "export") return <Badge tone="primary">Veri dışa aktarma</Badge>;
  return <Badge tone="danger">Veri silme</Badge>;
}

function statusBadge(status) {
  if (status === "done") return <Badge tone="success">tamamlandı</Badge>;
  if (status === "in_progress") return <Badge tone="warning">işlemde</Badge>;
  return <Badge tone="neutral">yeni</Badge>;
}

export default function Requests() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [rows, setRows] = useState([]);

  async function load() {
    const { data, error: err } = await supabase
      .from("account_requests")
      .select("*")
      .order("created_at", { ascending: false });
    if (err) throw err;
    setRows(data || []);
  }

  useEffect(() => {
    let active = true;
    (async () => {
      try {
        await load();
      } catch (e) {
        if (active) setError(e.message || String(e));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, []);

  async function setStatus(id, status) {
    const { error: err } = await supabase
      .from("account_requests")
      .update({ status })
      .eq("id", id);
    if (err) {
      setError(err.message);
      return;
    }
    setRows((prev) => prev.map((r) => (r.id === id ? { ...r, status } : r)));
  }

  if (loading) return <Spinner />;

  const open = rows.filter((r) => r.status !== "done").length;

  return (
    <>
      <PageHeader title="Talepler (KVKK)" subtitle="Veri silme / dışa aktarma istekleri" />
      {error && <div className="error-box">{error}</div>}

      <div className="grid stat-grid" style={{ marginBottom: 16 }}>
        <StatCard label="Toplam talep" value={rows.length} accent="primary" icon="📨" />
        <StatCard label="Açık talep" value={open} accent="warning" icon="⏳" />
      </div>

      <Card>
        <Table
          empty="Henüz talep yok."
          columns={[
            { key: "email", header: "E-posta", render: (r) => r.email || "—" },
            { key: "type", header: "Tür", render: (r) => typeBadge(r.type) },
            { key: "status", header: "Durum", render: (r) => statusBadge(r.status) },
            { key: "note", header: "Not", render: (r) => r.note || "—" },
            { key: "created_at", header: "Tarih", render: (r) => formatDate(r.created_at, true) },
            {
              key: "actions",
              header: "İşlem",
              render: (r) => (
                <div className="row gap" style={{ flexWrap: "wrap" }}>
                  {r.user_id && (
                    <button
                      className="btn"
                      style={{ padding: "5px 10px", fontSize: 12 }}
                      onClick={() => navigate(`/users/${r.user_id}`)}
                    >
                      Kullanıcı
                    </button>
                  )}
                  {r.status !== "done" && (
                    <button
                      className="btn btn-primary"
                      style={{ padding: "5px 10px", fontSize: 12 }}
                      onClick={() => setStatus(r.id, "done")}
                    >
                      Tamamlandı
                    </button>
                  )}
                </div>
              ),
            },
          ]}
          rows={rows}
        />
      </Card>
    </>
  );
}
