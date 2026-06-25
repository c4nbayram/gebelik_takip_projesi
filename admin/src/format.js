export function formatMoney(amount, currency = "TRY") {
  const value = Number(amount || 0);
  try {
    return new Intl.NumberFormat("tr-TR", {
      style: "currency",
      currency,
      maximumFractionDigits: 2,
    }).format(value);
  } catch {
    return `${value.toFixed(2)} ${currency}`;
  }
}

export function formatDate(value, withTime = false) {
  if (!value) return "—";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return "—";
  const opts = withTime
    ? { day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" }
    : { day: "2-digit", month: "short", year: "numeric" };
  return new Intl.DateTimeFormat("tr-TR", opts).format(d);
}

export function dayKey(value) {
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return "";
  return d.toISOString().slice(0, 10);
}

const PLAN_LABELS = {
  free: "Ücretsiz",
  premium_monthly: "Premium Aylık",
  premium_yearly: "Premium Yıllık",
};

export function planLabel(code) {
  return PLAN_LABELS[code] || code || "—";
}

const ROLE_LABELS = {
  Annesiyim: "Anne",
  Babasiyim: "Baba",
  Abisiyim: "Abi",
  Halasiyim: "Hala",
  Babannesiyim: "Babaanne",
  Teyzesiyim: "Teyze",
};

export function roleLabel(role) {
  if (!role) return "—";
  return ROLE_LABELS[role] || role;
}
