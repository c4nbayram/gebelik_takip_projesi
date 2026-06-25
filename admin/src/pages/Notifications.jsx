import { useEffect, useState } from "react";
import { supabase } from "../supabaseClient.js";
import { PageHeader, Card, Table, Badge, Spinner } from "../components/ui.jsx";
import { formatDate } from "../format.js";

const ICON_OPTIONS = [
  { value: "campaign_rounded", label: "📣 Duyuru" },
  { value: "info_rounded", label: "ℹ️ Bilgi" },
  { value: "local_drink_rounded", label: "💧 Su" },
  { value: "monitor_heart_rounded", label: "🩺 Sağlık" },
  { value: "medication_rounded", label: "💊 İlaç" },
  { value: "eco_rounded", label: "🌱 Gelişim" },
];

export default function Notifications() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [rows, setRows] = useState([]);
  const [profiles, setProfiles] = useState([]);
  const [profileMap, setProfileMap] = useState({});
  const [subs, setSubs] = useState([]);

  const [audience, setAudience] = useState("all");
  const [targetUser, setTargetUser] = useState("");
  const [segmentType, setSegmentType] = useState("premium");
  const [cityValue, setCityValue] = useState("");
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [icon, setIcon] = useState("campaign_rounded");
  const [sending, setSending] = useState(false);
  const [notice, setNotice] = useState("");

  async function loadList() {
    const [n, p, s] = await Promise.all([
      supabase.from("notifications").select("*").order("created_at", { ascending: false }).limit(100),
      supabase.from("profiles").select("id,name,email,city").order("name"),
      supabase.from("subscriptions").select("user_id,plan_code,status,expires_at"),
    ]);
    if (n.error) throw n.error;
    const map = {};
    for (const pr of p.data || []) map[pr.id] = pr;
    setProfileMap(map);
    setProfiles(p.data || []);
    setSubs(s.data || []);
    setRows(n.data || []);
  }

  function premiumUserIds() {
    const now = new Date();
    return new Set(
      (subs || [])
        .filter(
          (x) =>
            x.status === "active" &&
            (!x.expires_at || new Date(x.expires_at) > now) &&
            x.plan_code &&
            x.plan_code !== "free"
        )
        .map((x) => x.user_id)
    );
  }

  useEffect(() => {
    let active = true;
    (async () => {
      try {
        await loadList();
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

  async function handleSend(e) {
    e.preventDefault();
    setNotice("");
    setError("");
    if (!title.trim()) {
      setError("Başlık zorunlu.");
      return;
    }
    if (audience === "user" && !targetUser) {
      setError("Hedef kullanıcı seç.");
      return;
    }
    if (audience === "segment" && segmentType === "city" && !cityValue.trim()) {
      setError("Şehir gir.");
      return;
    }
    setSending(true);
    try {
      const { data: userRes } = await supabase.auth.getUser();
      const createdBy = userRes?.user?.id ?? null;

      if (audience === "segment") {
        const premium = premiumUserIds();
        let targets = [];
        if (segmentType === "premium") targets = profiles.filter((p) => premium.has(p.id));
        else if (segmentType === "free") targets = profiles.filter((p) => !premium.has(p.id));
        else
          targets = profiles.filter(
            (p) => (p.city || "").toLowerCase() === cityValue.trim().toLowerCase()
          );
        if (targets.length === 0) {
          setError("Eşleşen kullanıcı yok.");
          setSending(false);
          return;
        }
        const rows = targets.map((t) => ({
          audience: "user",
          user_id: t.id,
          title: title.trim(),
          body: body.trim() || null,
          category: "announcement",
          icon,
          created_by: createdBy,
        }));
        const { error: insErr } = await supabase.from("notifications").insert(rows);
        if (insErr) throw insErr;
        setNotice(`${targets.length} kullanıcıya gönderildi.`);
      } else {
        const payload = {
          audience,
          user_id: audience === "user" ? targetUser : null,
          title: title.trim(),
          body: body.trim() || null,
          category: audience === "all" ? "announcement" : "message",
          icon,
          created_by: createdBy,
        };
        const { error: insErr } = await supabase.from("notifications").insert(payload);
        if (insErr) throw insErr;
        setNotice(
          audience === "all"
            ? "Bildirim tüm kullanıcılara gönderildi."
            : "Bildirim seçilen kullanıcıya gönderildi."
        );
      }
      setTitle("");
      setBody("");
      setTargetUser("");
      await loadList();
    } catch (e) {
      setError(e.message || String(e));
    } finally {
      setSending(false);
    }
  }

  if (loading) return <Spinner />;

  return (
    <>
      <PageHeader title="Bildirimler" subtitle="Kullanıcılara bildirim gönder ve geçmişi gör" />

      <div className="cols-2 section-gap">
        <Card title="Yeni bildirim">
          <form onSubmit={handleSend}>
            {error && <div className="error-box">{error}</div>}
            {notice && (
              <div className="error-box" style={{ background: "rgba(95,211,164,.14)", borderColor: "rgba(95,211,164,.4)", color: "#5fd3a4" }}>
                {notice}
              </div>
            )}

            <div className="field">
              <label>Hedef kitle</label>
              <select value={audience} onChange={(e) => setAudience(e.target.value)}>
                <option value="all">Tüm kullanıcılar</option>
                <option value="user">Belirli kullanıcı</option>
                <option value="segment">Segment (premium / ücretsiz / şehir)</option>
              </select>
            </div>

            {audience === "segment" && (
              <>
                <div className="field">
                  <label>Segment</label>
                  <select value={segmentType} onChange={(e) => setSegmentType(e.target.value)}>
                    <option value="premium">Premium üyeler</option>
                    <option value="free">Ücretsiz kullanıcılar</option>
                    <option value="city">Şehre göre</option>
                  </select>
                </div>
                {segmentType === "city" && (
                  <div className="field">
                    <label>Şehir</label>
                    <input
                      value={cityValue}
                      onChange={(e) => setCityValue(e.target.value)}
                      placeholder="ör. İstanbul"
                    />
                  </div>
                )}
              </>
            )}

            {audience === "user" && (
              <div className="field">
                <label>Kullanıcı</label>
                <select value={targetUser} onChange={(e) => setTargetUser(e.target.value)}>
                  <option value="">Seç…</option>
                  {profiles.map((p) => (
                    <option key={p.id} value={p.id}>
                      {(p.name || "İsimsiz") + " — " + (p.email || p.id)}
                    </option>
                  ))}
                </select>
              </div>
            )}

            <div className="field">
              <label>Başlık</label>
              <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Örn: Yeni içerik yayında!" />
            </div>

            <div className="field">
              <label>Mesaj</label>
              <textarea rows={3} value={body} onChange={(e) => setBody(e.target.value)} placeholder="Bildirim metni…" />
            </div>

            <div className="field">
              <label>Simge</label>
              <select value={icon} onChange={(e) => setIcon(e.target.value)}>
                {ICON_OPTIONS.map((o) => (
                  <option key={o.value} value={o.value}>
                    {o.label}
                  </option>
                ))}
              </select>
            </div>

            <button className="btn btn-primary full" type="submit" disabled={sending}>
              {sending ? "Gönderiliyor…" : "Bildirimi Gönder"}
            </button>
          </form>
        </Card>

        <Card title="Gönderilen bildirimler">
          <Table
            empty="Henüz bildirim yok."
            columns={[
              {
                key: "audience",
                header: "Kitle",
                render: (r) =>
                  r.audience === "all" ? (
                    <Badge tone="primary">Herkes</Badge>
                  ) : (
                    <Badge tone="neutral">{profileMap[r.user_id]?.email || "Kullanıcı"}</Badge>
                  ),
              },
              { key: "title", header: "Başlık" },
              { key: "created_at", header: "Tarih", render: (r) => formatDate(r.created_at, true) },
            ]}
            rows={rows}
          />
        </Card>
      </div>
    </>
  );
}
