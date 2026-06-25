import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "../supabaseClient.js";
import { PageHeader, Card, Table, Badge, Spinner } from "../components/ui.jsx";
import { formatDate, planLabel, roleLabel } from "../format.js";

export default function Users() {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [profiles, setProfiles] = useState([]);
  const [planByUser, setPlanByUser] = useState({});
  const [query, setQuery] = useState("");

  useEffect(() => {
    let active = true;
    async function load() {
      setLoading(true);
      try {
        const [p, s] = await Promise.all([
          supabase.from("profiles").select("*").order("created_at", { ascending: false }),
          supabase.from("subscriptions").select("user_id,plan_code,status,expires_at"),
        ]);
        if (!active) return;
        if (p.error) throw p.error;
        const map = {};
        for (const sub of s.data || []) {
          const activeSub =
            sub.status === "active" && (!sub.expires_at || new Date(sub.expires_at) > new Date());
          if (activeSub && sub.plan_code && sub.plan_code !== "free") {
            map[sub.user_id] = sub.plan_code;
          }
        }
        setProfiles(p.data || []);
        setPlanByUser(map);
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

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return profiles;
    return profiles.filter((p) =>
      [p.name, p.email, p.city, p.baby_name].filter(Boolean).some((v) => v.toLowerCase().includes(q))
    );
  }, [profiles, query]);

  function exportCsv() {
    const header = ["Ad", "E-posta", "Rol", "Sehir", "Bebek", "Paket", "Kayit"];
    const esc = (v) => `"${String(v ?? "").replace(/"/g, '""')}"`;
    const lines = filtered.map((p) =>
      [
        p.name,
        p.email,
        roleLabel(p.caregiver_role),
        p.city,
        p.baby_name,
        planByUser[p.id] ? planLabel(planByUser[p.id]) : "Ucretsiz",
        p.created_at,
      ]
        .map(esc)
        .join(",")
    );
    const csv = [header.join(","), ...lines].join("\n");
    const blob = new Blob(["﻿" + csv], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "kullanicilar.csv";
    a.click();
    URL.revokeObjectURL(url);
  }

  if (loading) return <Spinner />;

  return (
    <>
      <PageHeader
        title="Kullanıcılar"
        subtitle={`${profiles.length} kayıtlı kullanıcı`}
        actions={
          <button className="btn" onClick={exportCsv}>⬇ CSV indir</button>
        }
      />
      {error && <div className="error-box">{error}</div>}

      <div className="toolbar">
        <input
          placeholder="İsim, e-posta, şehir veya bebek adı ara…"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        <span className="muted small">{filtered.length} sonuç</span>
      </div>

      <Card>
        <Table
          empty="Eşleşen kullanıcı yok."
          onRowClick={(r) => navigate(`/users/${r.id}`)}
          columns={[
            { key: "name", header: "İsim", render: (r) => r.name || "—" },
            { key: "email", header: "E-posta", render: (r) => r.email || "—" },
            { key: "role", header: "Rol", render: (r) => roleLabel(r.caregiver_role) },
            { key: "city", header: "Şehir", render: (r) => r.city || "—" },
            { key: "baby", header: "Bebek", render: (r) => r.baby_name || "—" },
            {
              key: "plan",
              header: "Paket",
              render: (r) =>
                planByUser[r.id] ? (
                  <Badge tone="primary">{planLabel(planByUser[r.id])}</Badge>
                ) : (
                  <Badge tone="neutral">Ücretsiz</Badge>
                ),
            },
            { key: "created_at", header: "Kayıt", render: (r) => formatDate(r.created_at) },
          ]}
          rows={filtered}
        />
      </Card>
    </>
  );
}
