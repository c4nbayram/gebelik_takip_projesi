import { useEffect, useState } from "react";
import { supabase } from "../supabaseClient.js";
import { PageHeader, Card, Table, Badge, Spinner } from "../components/ui.jsx";

function toFormValue(field, value) {
  if (field.type === "csv") return Array.isArray(value) ? value.join(", ") : "";
  if (field.type === "lines") return Array.isArray(value) ? value.join("\n") : "";
  if (field.type === "bool") return value === true;
  if (value === null || value === undefined) return "";
  return value;
}

function fromFormValue(field, value) {
  if (field.type === "number") return value === "" ? null : Number(value);
  if (field.type === "bool") return Boolean(value);
  if (field.type === "csv")
    return String(value || "")
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);
  if (field.type === "lines")
    return String(value || "")
      .split("\n")
      .map((s) => s.trim())
      .filter(Boolean);
  return value === "" ? null : value;
}

function EditModal({ title, fields, initial, onClose, onSave }) {
  const [form, setForm] = useState(() => {
    const f = {};
    for (const fld of fields) f[fld.key] = toFormValue(fld, initial?.[fld.key]);
    return f;
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  function set(k, v) {
    setForm((prev) => ({ ...prev, [k]: v }));
  }

  async function handleSave() {
    setSaving(true);
    setError("");
    const payload = {};
    for (const fld of fields) payload[fld.key] = fromFormValue(fld, form[fld.key]);
    const res = await onSave(payload);
    setSaving(false);
    if (res?.error) setError(res.error);
    else onClose();
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h2>{title}</h2>
        {error && <div className="error-box">{error}</div>}
        {fields.map((fld) =>
          fld.type === "bool" ? (
            <div className="switch-row" key={fld.key}>
              <input
                type="checkbox"
                checked={!!form[fld.key]}
                onChange={(e) => set(fld.key, e.target.checked)}
                id={`f-${fld.key}`}
              />
              <label htmlFor={`f-${fld.key}`} style={{ margin: 0 }}>{fld.label}</label>
            </div>
          ) : (
            <div className="field" key={fld.key}>
              <label>{fld.label}{fld.hint ? ` (${fld.hint})` : ""}</label>
              {fld.type === "textarea" || fld.type === "lines" ? (
                <textarea
                  rows={fld.type === "lines" ? 4 : 3}
                  value={form[fld.key]}
                  onChange={(e) => set(fld.key, e.target.value)}
                />
              ) : (
                <input
                  type={fld.type === "number" ? "number" : "text"}
                  value={form[fld.key]}
                  onChange={(e) => set(fld.key, e.target.value)}
                />
              )}
            </div>
          )
        )}
        <div className="modal-actions">
          <button className="btn" onClick={onClose} disabled={saving}>Vazgeç</button>
          <button className="btn btn-primary" onClick={handleSave} disabled={saving}>
            {saving ? "Kaydediliyor…" : "Kaydet"}
          </button>
        </div>
      </div>
    </div>
  );
}

function CrudSection({ table, singular, orderBy, fields, columns, makeEmpty }) {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [editing, setEditing] = useState(null);

  async function load() {
    setLoading(true);
    const { data, error: err } = await supabase.from(table).select("*").order(orderBy);
    if (err) setError(err.message);
    else setRows(data || []);
    setLoading(false);
  }

  useEffect(() => {
    load();
  }, []);

  async function save(payload) {
    if (editing && editing !== "new" && editing.id) {
      const { error: err } = await supabase.from(table).update(payload).eq("id", editing.id);
      if (err) return { error: err.message };
    } else {
      const { error: err } = await supabase.from(table).insert(payload);
      if (err) return { error: err.message };
    }
    await load();
    return {};
  }

  async function remove(row) {
    if (!window.confirm(`"${row[columns[0].key]}" silinsin mi?`)) return;
    const { error: err } = await supabase.from(table).delete().eq("id", row.id);
    if (err) setError(err.message);
    else load();
  }

  async function toggleActive(row) {
    const { error: err } = await supabase
      .from(table)
      .update({ is_active: !row.is_active })
      .eq("id", row.id);
    if (err) setError(err.message);
    else load();
  }

  if (loading) return <Spinner />;

  const cols = [
    ...columns,
    {
      key: "active",
      header: "Aktif",
      render: (r) =>
        r.is_active ? <Badge tone="success">aktif</Badge> : <Badge tone="neutral">pasif</Badge>,
    },
    {
      key: "actions",
      header: "İşlem",
      render: (r) => (
        <div className="row gap" style={{ flexWrap: "wrap" }}>
          <button className="btn" style={{ padding: "5px 10px", fontSize: 12 }} onClick={() => setEditing(r)}>
            Düzenle
          </button>
          <button className="btn" style={{ padding: "5px 10px", fontSize: 12 }} onClick={() => toggleActive(r)}>
            {r.is_active ? "Pasifleştir" : "Aktifleştir"}
          </button>
          <button
            className="btn"
            style={{ padding: "5px 10px", fontSize: 12, color: "#ff7e8c" }}
            onClick={() => remove(r)}
          >
            Sil
          </button>
        </div>
      ),
    },
  ];

  return (
    <Card
      title={`${rows.length} kayıt`}
      actions={
        <button className="btn btn-primary" onClick={() => setEditing("new")}>+ {singular} ekle</button>
      }
    >
      {error && <div className="error-box">{error}</div>}
      <Table empty="Kayıt yok." columns={cols} rows={rows} />
      {editing && (
        <EditModal
          title={editing === "new" ? `Yeni ${singular}` : `${singular} düzenle`}
          fields={fields}
          initial={editing === "new" ? makeEmpty() : editing}
          onClose={() => setEditing(null)}
          onSave={save}
        />
      )}
    </Card>
  );
}

const TABS = [
  { key: "premium", label: "Premium İçerik" },
  { key: "templates", label: "Bildirim Şablonları" },
  { key: "plans", label: "Paketler" },
];

export default function Content() {
  const [tab, setTab] = useState("premium");

  return (
    <>
      <PageHeader
        title="İçerik Yönetimi"
        subtitle="Premium içerik, bildirim şablonları ve paketleri buradan yönet"
      />
      <div className="tabs">
        {TABS.map((t) => (
          <div
            key={t.key}
            className={tab === t.key ? "tab active" : "tab"}
            onClick={() => setTab(t.key)}
          >
            {t.label}
          </div>
        ))}
      </div>

      {tab === "premium" && (
        <CrudSection
          table="premium_contents"
          singular="içerik"
          orderBy="sort_order"
          makeEmpty={() => ({ is_active: true, sort_order: 0, required_feature: "premium_content" })}
          columns={[
            { key: "title", header: "Başlık" },
            { key: "category", header: "Kategori", render: (r) => r.category || "—" },
          ]}
          fields={[
            { key: "title", label: "Başlık", type: "text" },
            { key: "category", label: "Kategori", type: "text" },
            { key: "icon", label: "Simge adı", type: "text", hint: "ör. restaurant_rounded" },
            { key: "summary", label: "Özet", type: "textarea" },
            { key: "body", label: "İçerik", type: "textarea" },
            { key: "sort_order", label: "Sıra", type: "number" },
            { key: "is_active", label: "Aktif", type: "bool" },
          ]}
        />
      )}

      {tab === "templates" && (
        <CrudSection
          table="notification_templates"
          singular="şablon"
          orderBy="id"
          makeEmpty={() => ({ is_active: true, schedule_minute: 0 })}
          columns={[
            { key: "key", header: "Anahtar" },
            { key: "title", header: "Başlık" },
            {
              key: "time",
              header: "Saat",
              render: (r) =>
                r.schedule_hour == null
                  ? "—"
                  : `${String(r.schedule_hour).padStart(2, "0")}:${String(r.schedule_minute || 0).padStart(2, "0")}`,
            },
          ]}
          fields={[
            { key: "key", label: "Anahtar", type: "text", hint: "benzersiz, ör. su_ic" },
            { key: "title", label: "Başlık", type: "text" },
            { key: "body", label: "Mesaj", type: "textarea" },
            { key: "icon", label: "Simge adı", type: "text" },
            { key: "schedule_hour", label: "Saat (0-23)", type: "number" },
            { key: "schedule_minute", label: "Dakika", type: "number" },
            { key: "is_active", label: "Aktif", type: "bool" },
          ]}
        />
      )}

      {tab === "plans" && (
        <CrudSection
          table="plans"
          singular="paket"
          orderBy="sort_order"
          makeEmpty={() => ({ is_active: true, currency: "TRY", period: "monthly", features: [], perks: [], sort_order: 0 })}
          columns={[
            { key: "name", header: "Ad" },
            { key: "price", header: "Fiyat", render: (r) => `${r.price} ${r.currency}` },
            { key: "duration_months", header: "Süre (ay)", render: (r) => r.duration_months ?? "—" },
          ]}
          fields={[
            { key: "code", label: "Kod", type: "text", hint: "benzersiz, ör. premium_monthly" },
            { key: "name", label: "Ad", type: "text" },
            { key: "description", label: "Açıklama", type: "text" },
            { key: "price", label: "Fiyat", type: "number" },
            { key: "currency", label: "Para birimi", type: "text" },
            { key: "period", label: "Periyot", type: "text", hint: "monthly|quarter|pregnancy|lifetime" },
            { key: "duration_months", label: "Süre (ay)", type: "number", hint: "boş = ömür boyu" },
            { key: "features", label: "Özellikler", type: "csv", hint: "virgülle: rehber, detayli_degerlendirme, premium_content" },
            { key: "perks", label: "Avantajlar", type: "lines", hint: "her satır bir madde" },
            { key: "sort_order", label: "Sıra", type: "number" },
            { key: "is_active", label: "Aktif", type: "bool" },
          ]}
        />
      )}
    </>
  );
}
