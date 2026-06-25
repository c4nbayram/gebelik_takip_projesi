import { useEffect, useState } from "react";
import { useParams, Link } from "react-router-dom";
import { supabase } from "../supabaseClient.js";
import { PageHeader, Card, Table, Badge, Spinner, StatCard } from "../components/ui.jsx";
import { formatMoney, formatDate, planLabel, roleLabel } from "../format.js";

function Row({ label, value }) {
  return (
    <>
      <dt>{label}</dt>
      <dd>{value || "—"}</dd>
    </>
  );
}

export default function UserDetail() {
  const { id } = useParams();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [data, setData] = useState(null);
  const [tick, setTick] = useState(0);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    let active = true;
    async function load() {
      setLoading(true);
      setError("");
      try {
        const [profile, subs, payments, weeks, appts, meds, aiLogs, chat, symptoms, babyLogs, counts] = await Promise.all([
          supabase.from("profiles").select("*").eq("id", id).maybeSingle(),
          supabase.from("subscriptions").select("*").eq("user_id", id).order("started_at", { ascending: false }),
          supabase.from("payments").select("*").eq("user_id", id).order("created_at", { ascending: false }),
          supabase.from("week_entries").select("*").eq("user_id", id).order("week_no"),
          supabase.from("appointments").select("*").eq("user_id", id).order("appointment_at"),
          supabase.from("medications").select("*").eq("user_id", id),
          supabase.from("analysis_logs").select("*").eq("user_id", id).order("created_at", { ascending: false }),
          supabase.from("chat_messages").select("*").eq("user_id", id).order("created_at", { ascending: true }),
          supabase.from("symptom_logs").select("*").eq("user_id", id).order("logged_on", { ascending: false }),
          supabase.from("baby_logs").select("*").eq("user_id", id).order("occurred_at", { ascending: false }),
          Promise.all([
            supabase.from("kick_sessions").select("*", { count: "exact", head: true }).eq("user_id", id),
            supabase.from("weight_entries").select("*", { count: "exact", head: true }).eq("user_id", id),
            supabase.from("journal_entries").select("*", { count: "exact", head: true }).eq("user_id", id),
            supabase.from("baby_names").select("*", { count: "exact", head: true }).eq("user_id", id),
          ]),
        ]);
        if (!active) return;
        if (profile.error) throw profile.error;
        const [kick, weight, journal, names] = counts;
        setData({
          profile: profile.data,
          subs: subs.data || [],
          payments: payments.data || [],
          weeks: weeks.data || [],
          appts: appts.data || [],
          meds: meds.data || [],
          aiLogs: aiLogs.data || [],
          chat: chat.data || [],
          symptoms: symptoms.data || [],
          babyLogs: babyLogs.data || [],
          activity: {
            kick: kick.count || 0,
            weight: weight.count || 0,
            journal: journal.count || 0,
            names: names.count || 0,
            chat: (chat.data || []).length,
          },
        });
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
  }, [id, tick]);

  async function grantPremium() {
    setBusy(true);
    const now = new Date();
    const expires = new Date(now);
    expires.setMonth(expires.getMonth() + 1);
    const { error: err } = await supabase.from("subscriptions").insert({
      user_id: id,
      plan_code: "premium_monthly",
      plan_name: "Premium (Yönetici tanımlı)",
      price: 0,
      currency: "TRY",
      status: "active",
      started_at: now.toISOString(),
      expires_at: expires.toISOString(),
    });
    setBusy(false);
    if (err) setError(err.message);
    else setTick((t) => t + 1);
  }

  async function cancelPremium() {
    setBusy(true);
    const { error: err } = await supabase
      .from("subscriptions")
      .update({ status: "cancelled" })
      .eq("user_id", id)
      .eq("status", "active");
    setBusy(false);
    if (err) setError(err.message);
    else setTick((t) => t + 1);
  }

  async function toggleActive(active) {
    setBusy(true);
    const { error: err } = await supabase
      .from("profiles")
      .update({ is_active: active })
      .eq("id", id);
    setBusy(false);
    if (err) setError(err.message);
    else setTick((t) => t + 1);
  }

  if (loading) return <Spinner />;
  if (error) return <div className="error-box">{error}</div>;
  if (!data || !data.profile) {
    return (
      <>
        <Link to="/users" className="back-link">← Kullanıcılar</Link>
        <div className="error-box">Kullanıcı bulunamadı.</div>
      </>
    );
  }

  const { profile, subs, payments, weeks, appts, meds, aiLogs, chat, symptoms, babyLogs, activity } = data;

  const severityLabel = (s) => (s === 3 ? "Şiddetli" : s === 2 ? "Orta" : "Hafif");
  const severityTone = (s) => (s === 3 ? "danger" : s === 2 ? "warning" : "success");
  const babyTypeLabel = (t) =>
    t === "feeding" ? "Beslenme" : t === "sleep" ? "Uyku" : t === "diaper" ? "Bez" : t;
  const activeSub = subs.find(
    (s) => s.status === "active" && (!s.expires_at || new Date(s.expires_at) > new Date()) && s.plan_code !== "free"
  );

  return (
    <>
      <Link to="/users" className="back-link">← Kullanıcılar</Link>
      <PageHeader
        title={profile.name || profile.email || "Kullanıcı"}
        subtitle={profile.email}
        actions={
          activeSub ? (
            <Badge tone="primary">{planLabel(activeSub.plan_code)}</Badge>
          ) : (
            <Badge tone="neutral">Ücretsiz</Badge>
          )
        }
      />

      <Card title="Yönetim İşlemleri">
        {error && <div className="error-box">{error}</div>}
        <div className="row gap" style={{ flexWrap: "wrap" }}>
          {activeSub ? (
            <button className="btn" disabled={busy} onClick={cancelPremium}>
              Premium'u iptal et
            </button>
          ) : (
            <button className="btn btn-primary" disabled={busy} onClick={grantPremium}>
              Premium ver (1 ay)
            </button>
          )}
          {profile.is_active === false ? (
            <button className="btn btn-primary" disabled={busy} onClick={() => toggleActive(true)}>
              Hesabı aktifleştir
            </button>
          ) : (
            <button
              className="btn"
              style={{ color: "#ff7e8c" }}
              disabled={busy}
              onClick={() => toggleActive(false)}
            >
              Hesabı pasifleştir
            </button>
          )}
        </div>
        <div className="muted small" style={{ marginTop: 10 }}>
          Durum: {profile.is_active === false ? "Pasif (giriş engelli)" : "Aktif"}
          {activeSub ? " · Premium aktif" : " · Ücretsiz"}
        </div>
      </Card>
      <div style={{ height: 16 }} />

      <div className="cols-2 section-gap">
        <div className="section-gap">
          <Card title="Kişisel bilgiler">
            <dl className="kv">
              <Row label="Ad" value={profile.name} />
              <Row label="E-posta" value={profile.email} />
              <Row label="Yaş" value={profile.age} />
              <Row label="Rol" value={roleLabel(profile.caregiver_role)} />
              <Row label="Bebek adı" value={profile.baby_name} />
              <Row label="Şehir" value={profile.city} />
              <Row
                label="Planlama mı?"
                value={profile.planning_baby ? "Evet (bebek planlıyor)" : "Hayır (aktif takip)"}
              />
              <Row label="Son adet" value={formatDate(profile.last_period_start)} />
              <Row label="Tahmini doğum" value={formatDate(profile.estimated_due_date)} />
              <Row label="Doğum tarihi" value={formatDate(profile.baby_birth_date)} />
              <Row label="Sağlık geçmişi" value={profile.medical_history} />
              <Row label="Kronik rahatsızlık" value={profile.maternal_chronic} />
              <Row label="Kayıt tarihi" value={formatDate(profile.created_at, true)} />
            </dl>
          </Card>

          <Card title="Haftalık ölçümler">
            <Table
              empty="Henüz ölçüm girilmemiş."
              columns={[
                { key: "week_no", header: "Hafta" },
                { key: "systolic", header: "Sis." },
                { key: "diastolic", header: "Dia." },
                { key: "blood_sugar", header: "Şeker" },
                { key: "body_temp", header: "Ateş" },
                { key: "heart_rate", header: "Nabız" },
                {
                  key: "risk",
                  header: "Risk",
                  render: (r) =>
                    r.risk_label ? (
                      <Badge
                        tone={
                          /high|yuksek|yüksek/i.test(r.risk_label)
                            ? "danger"
                            : /mid|orta/i.test(r.risk_label)
                            ? "warning"
                            : "success"
                        }
                      >
                        {r.risk_label} {Math.round((r.risk_score || 0) * 100)}%
                      </Badge>
                    ) : (
                      "—"
                    ),
                },
              ]}
              rows={weeks}
            />
          </Card>
        </div>

        <div className="section-gap">
          <Card title="Üyelik & ödemeler">
            {activeSub ? (
              <dl className="kv" style={{ marginBottom: 14 }}>
                <Row label="Aktif paket" value={planLabel(activeSub.plan_code)} />
                <Row label="Ücret" value={formatMoney(activeSub.price, activeSub.currency)} />
                <Row label="Başlangıç" value={formatDate(activeSub.started_at, true)} />
                <Row label="Bitiş" value={activeSub.expires_at ? formatDate(activeSub.expires_at, true) : "Ömür boyu"} />
              </dl>
            ) : (
              <p className="muted" style={{ marginTop: 0 }}>Aktif premium aboneliği yok.</p>
            )}
            <Table
              empty="Ödeme kaydı yok."
              columns={[
                { key: "plan", header: "Paket", render: (r) => planLabel(r.plan_code) },
                { key: "amount", header: "Tutar", render: (r) => formatMoney(r.amount, r.currency) },
                {
                  key: "status",
                  header: "Durum",
                  render: (r) => <Badge tone={r.status === "paid" ? "success" : "warning"}>{r.status}</Badge>,
                },
                { key: "created_at", header: "Tarih", render: (r) => formatDate(r.created_at, true) },
              ]}
              rows={payments}
            />
          </Card>

          <Card title="Aktivite">
            <div className="grid stat-grid">
              <StatCard label="Randevu" value={appts.length} accent="primary" />
              <StatCard label="İlaç" value={meds.length} accent="accent" />
              <StatCard label="Tekme seansı" value={activity.kick} accent="success" />
              <StatCard label="Kilo kaydı" value={activity.weight} accent="warning" />
              <StatCard label="Günlük" value={activity.journal} accent="primary" />
              <StatCard label="Bebek ismi" value={activity.names} accent="accent" />
              <StatCard label="Sohbet mesajı" value={activity.chat} accent="success" />
            </div>
          </Card>
        </div>
      </div>

      <div className="section-gap" style={{ marginTop: 16 }}>
        <Card title={`Risk Değerlendirme Geçmişi (${aiLogs.length})`}>
          <Table
            empty="Bu kullanıcı için risk değerlendirme kaydı yok."
            columns={[
              { key: "week_no", header: "Hafta", render: (r) => (r.week_no ?? "—") + ". hafta" },
              {
                key: "risk",
                header: "Risk",
                render: (r) =>
                  r.risk_label ? (
                    <Badge
                      tone={
                        /high|yuksek|yüksek/i.test(r.risk_label)
                          ? "danger"
                          : /mid|orta/i.test(r.risk_label)
                          ? "warning"
                          : "success"
                      }
                    >
                      {r.risk_label} {Math.round((r.risk_score || 0) * 100)}%
                    </Badge>
                  ) : (
                    "—"
                  ),
              },
              {
                key: "source",
                header: "Kaynak",
                render: (r) => (r.source === "dataset" ? "Veri seti (KNN)" : "Çevrimdışı"),
              },
              {
                key: "knn",
                header: "Komşu (Y/O/D)",
                render: (r) => `${r.knn_high ?? 0}/${r.knn_mid ?? 0}/${r.knn_low ?? 0}`,
              },
              {
                key: "advice",
                header: "Rehberlik notu",
                render: (r) => (
                  <span
                    title={r.guidance_note || r.ai_advice || ""}
                    style={{
                      display: "inline-block",
                      maxWidth: 360,
                      whiteSpace: "nowrap",
                      overflow: "hidden",
                      textOverflow: "ellipsis",
                      verticalAlign: "bottom",
                    }}
                  >
                    {(r.guidance_note || r.ai_advice || "—").replace(/\n+/g, " · ")}
                  </span>
                ),
              },
              { key: "created_at", header: "Tarih", render: (r) => formatDate(r.created_at, true) },
            ]}
            rows={aiLogs}
          />
        </Card>

        <Card title={`Gebelik Rehberi Geçmişi (${chat.length})`}>
          {chat.length === 0 ? (
            <p className="muted" style={{ margin: 0 }}>Bu kullanıcı henüz gebelik rehberini kullanmamış.</p>
          ) : (
            <div style={{ display: "flex", flexDirection: "column", gap: 8, maxHeight: 460, overflowY: "auto" }}>
              {chat.map((m) => {
                const fromUser = m.from_user === true;
                return (
                  <div
                    key={m.id}
                    style={{
                      alignSelf: fromUser ? "flex-end" : "flex-start",
                      maxWidth: "78%",
                      background: fromUser ? "#6f5ae0" : "#262348",
                      color: fromUser ? "#fff" : "#e7e5ff",
                      border: fromUser ? "none" : "1px solid #2f2c57",
                      borderRadius: 12,
                      padding: "9px 12px",
                    }}
                  >
                    <div style={{ fontSize: 10.5, opacity: 0.7, marginBottom: 3 }}>
                      {fromUser ? "Kullanıcı" : "Gebelik Rehberi"} · {formatDate(m.created_at, true)}
                    </div>
                    <div style={{ fontSize: 13, lineHeight: 1.5, whiteSpace: "pre-wrap" }}>{m.message}</div>
                  </div>
                );
              })}
            </div>
          )}
        </Card>

        <Card title={`Belirti Geçmişi (${symptoms.length})`}>
          <Table
            empty="Bu kullanıcı için belirti kaydı yok."
            columns={[
              { key: "logged_on", header: "Tarih", render: (r) => formatDate(r.logged_on) },
              { key: "week_no", header: "Hafta", render: (r) => (r.week_no ?? "—") },
              {
                key: "symptoms",
                header: "Belirtiler",
                render: (r) => (
                  <div style={{ display: "flex", flexWrap: "wrap", gap: 6, maxWidth: 420 }}>
                    {(Array.isArray(r.symptoms) ? r.symptoms : []).map((s, i) => (
                      <span
                        key={i}
                        style={{
                          background: "#262348",
                          border: "1px solid #2f2c57",
                          borderRadius: 999,
                          padding: "2px 9px",
                          fontSize: 11.5,
                        }}
                      >
                        {s}
                      </span>
                    ))}
                  </div>
                ),
              },
              {
                key: "severity",
                header: "Şiddet",
                render: (r) => <Badge tone={severityTone(r.severity)}>{severityLabel(r.severity)}</Badge>,
              },
              { key: "note", header: "Not", render: (r) => r.note || "—" },
            ]}
            rows={symptoms}
          />
        </Card>

        <Card title={`Bebek Takibi (${babyLogs.length})`}>
          <Table
            empty="Doğum sonrası kayıt yok."
            columns={[
              { key: "type", header: "Tür", render: (r) => babyTypeLabel(r.type) },
              { key: "amount", header: "Miktar/Süre", render: (r) => r.amount || "—" },
              { key: "note", header: "Not", render: (r) => r.note || "—" },
              { key: "occurred_at", header: "Zaman", render: (r) => formatDate(r.occurred_at, true) },
            ]}
            rows={babyLogs}
          />
        </Card>
      </div>
    </>
  );
}
