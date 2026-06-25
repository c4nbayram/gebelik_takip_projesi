import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "../supabaseClient.js";
import { PageHeader, Card, Table, Badge, Spinner, StatCard } from "../components/ui.jsx";
import { formatDate } from "../format.js";

function statusBadge(status) {
  if (status === "resolved") return <Badge tone="success">çözüldü</Badge>;
  if (status === "read") return <Badge tone="neutral">okundu</Badge>;
  return <Badge tone="warning">yeni</Badge>;
}

export default function Support() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [rows, setRows] = useState([]);

  async function load() {
    const { data, error: err } = await supabase
      .from("support_messages")
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

  async function reply(row) {
    if (!row.user_id) {
      alert("Bu mesaj bir kullanıcı hesabına bağlı değil, bildirim gönderilemez.");
      return;
    }
    const text = window.prompt("Kullanıcıya yanıt (uygulamada bildirim olarak görünür):", "");
    if (!text || !text.trim()) return;
    const { data: userRes } = await supabase.auth.getUser();
    const { error: nErr } = await supabase.from("notifications").insert({
      audience: "user",
      user_id: row.user_id,
      title: "Destek yanıtı",
      body: text.trim(),
      category: "support",
      icon: "campaign_rounded",
      created_by: userRes?.user?.id ?? null,
    });
    if (nErr) {
      setError(nErr.message);
      return;
    }
    await supabase.from("support_messages").update({ status: "resolved" }).eq("id", row.id);
    setRows((prev) => prev.map((r) => (r.id === row.id ? { ...r, status: "resolved" } : r)));
  }

  async function setStatus(id, status) {
    const { error: err } = await supabase
      .from("support_messages")
      .update({ status })
      .eq("id", id);
    if (err) {
      setError(err.message);
      return;
    }
    setRows((prev) => prev.map((r) => (r.id === id ? { ...r, status } : r)));
  }

  if (loading) return <Spinner />;

  const newCount = rows.filter((r) => r.status === "new").length;

  return (
    <>
      <PageHeader title="Destek" subtitle="Kullanıcılardan gelen iletişim mesajları" />
      {error && <div className="error-box">{error}</div>}

      <div className="grid stat-grid" style={{ marginBottom: 16 }}>
        <StatCard label="Toplam mesaj" value={rows.length} accent="primary" icon="✉️" />
        <StatCard label="Yeni / açık" value={newCount} accent="warning" icon="🆕" />
      </div>

      <Card>
        <Table
          empty="Henüz destek mesajı yok."
          columns={[
            {
              key: "from",
              header: "Gönderen",
              render: (r) => (
                <div>
                  <div style={{ fontWeight: 700, color: "#f1f0ff" }}>{r.name || "—"}</div>
                  <div className="muted small">{r.email || "—"}</div>
                </div>
              ),
            },
            { key: "subject", header: "Konu", render: (r) => r.subject || "—" },
            {
              key: "message",
              header: "Mesaj",
              render: (r) => (
                <div style={{ maxWidth: 420, whiteSpace: "pre-wrap", lineHeight: 1.5 }}>
                  {r.message}
                </div>
              ),
            },
            { key: "status", header: "Durum", render: (r) => statusBadge(r.status) },
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
                  <button
                    className="btn btn-primary"
                    style={{ padding: "5px 10px", fontSize: 12 }}
                    onClick={() => reply(r)}
                  >
                    Yanıtla
                  </button>
                  {r.status !== "resolved" ? (
                    <button
                      className="btn"
                      style={{ padding: "5px 10px", fontSize: 12 }}
                      onClick={() => setStatus(r.id, "resolved")}
                    >
                      Çözüldü
                    </button>
                  ) : (
                    <button
                      className="btn"
                      style={{ padding: "5px 10px", fontSize: 12 }}
                      onClick={() => setStatus(r.id, "new")}
                    >
                      Yeniden aç
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
