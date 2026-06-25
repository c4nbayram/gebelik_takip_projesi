export function Spinner({ label = "Yükleniyor…" }) {
  return (
    <div className="center muted" style={{ padding: 40 }}>
      <div className="spinner" />
      <span style={{ marginTop: 12 }}>{label}</span>
    </div>
  );
}

export function PageHeader({ title, subtitle, actions }) {
  return (
    <div className="page-header">
      <div>
        <h1>{title}</h1>
        {subtitle && <p className="muted">{subtitle}</p>}
      </div>
      {actions && <div className="row gap">{actions}</div>}
    </div>
  );
}

export function StatCard({ label, value, sub, accent = "primary", icon }) {
  return (
    <div className={`stat-card accent-${accent}`}>
      {icon && <div className="stat-icon">{icon}</div>}
      <div className="stat-label">{label}</div>
      <div className="stat-value">{value}</div>
      {sub && <div className="stat-sub muted">{sub}</div>}
    </div>
  );
}

export function Card({ title, children, actions }) {
  return (
    <section className="card">
      {(title || actions) && (
        <div className="card-head">
          {title && <h2>{title}</h2>}
          {actions}
        </div>
      )}
      <div className="card-body">{children}</div>
    </section>
  );
}

export function Badge({ children, tone = "neutral" }) {
  return <span className={`badge badge-${tone}`}>{children}</span>;
}

export function EmptyState({ title = "Kayıt yok", description }) {
  return (
    <div className="empty">
      <div className="empty-title">{title}</div>
      {description && <div className="muted">{description}</div>}
    </div>
  );
}

export function Table({ columns, rows, keyField = "id", onRowClick, empty }) {
  if (!rows || rows.length === 0) {
    return <EmptyState description={empty} />;
  }
  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>
            {columns.map((c) => (
              <th key={c.key} style={c.width ? { width: c.width } : undefined}>
                {c.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr
              key={r[keyField]}
              onClick={onRowClick ? () => onRowClick(r) : undefined}
              className={onRowClick ? "clickable" : undefined}
            >
              {columns.map((c) => (
                <td key={c.key}>{c.render ? c.render(r) : r[c.key] ?? "—"}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
