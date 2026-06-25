class WeekSize {
  final String emoji;
  final String fruit;
  final String size;

  const WeekSize(this.emoji, this.fruit, this.size);
}

const Map<int, WeekSize> _sizes = {
  4: WeekSize("•", "haşhaş tohumu", "~2 mm"),
  5: WeekSize("•", "susam tanesi", "~3 mm"),
  6: WeekSize("🫛", "mercimek", "~5 mm"),
  7: WeekSize("🫐", "yaban mersini", "~1 cm"),
  8: WeekSize("🫐", "ahududu", "~1.6 cm · ~1 g"),
  9: WeekSize("🍒", "kiraz", "~2.3 cm · ~2 g"),
  10: WeekSize("🍓", "çilek", "~3.1 cm · ~4 g"),
  11: WeekSize("🫒", "incir", "~4.1 cm · ~7 g"),
  12: WeekSize("🍋‍🟩", "misket limonu", "~5.4 cm · ~14 g"),
  13: WeekSize("🫛", "bezelye kabuğu", "~7.4 cm · ~23 g"),
  14: WeekSize("🍋", "limon", "~8.7 cm · ~43 g"),
  15: WeekSize("🍎", "elma", "~10 cm · ~70 g"),
  16: WeekSize("🥑", "avokado", "~11.6 cm · ~100 g"),
  17: WeekSize("🥔", "şalgam", "~13 cm · ~140 g"),
  18: WeekSize("🫑", "biber", "~14 cm · ~190 g"),
  19: WeekSize("🍅", "domates", "~15 cm · ~240 g"),
  20: WeekSize("🍌", "muz", "~25 cm · ~300 g"),
  21: WeekSize("🥕", "havuç", "~27 cm · ~360 g"),
  22: WeekSize("🥬", "kabak", "~28 cm · ~430 g"),
  23: WeekSize("🍊", "greyfurt", "~29 cm · ~500 g"),
  24: WeekSize("🌽", "mısır", "~30 cm · ~600 g"),
  25: WeekSize("🥬", "karnabahar", "~34 cm · ~660 g"),
  26: WeekSize("🥬", "marul", "~35 cm · ~760 g"),
  27: WeekSize("🥦", "karnabahar", "~36 cm · ~875 g"),
  28: WeekSize("🍆", "patlıcan", "~37 cm · ~1 kg"),
  29: WeekSize("🎃", "balkabağı", "~38 cm · ~1.2 kg"),
  30: WeekSize("🥬", "lahana", "~39 cm · ~1.3 kg"),
  31: WeekSize("🥥", "hindistan cevizi", "~41 cm · ~1.5 kg"),
  32: WeekSize("🥬", "kereviz", "~42 cm · ~1.7 kg"),
  33: WeekSize("🍍", "ananas", "~43 cm · ~1.9 kg"),
  34: WeekSize("🍈", "kavun", "~45 cm · ~2.1 kg"),
  35: WeekSize("🍈", "bal kavunu", "~46 cm · ~2.4 kg"),
  36: WeekSize("🥬", "marul (romaine)", "~47 cm · ~2.6 kg"),
  37: WeekSize("🥬", "pazı", "~48 cm · ~2.9 kg"),
  38: WeekSize("🥬", "pırasa", "~49 cm · ~3.1 kg"),
  39: WeekSize("🍉", "mini karpuz", "~50 cm · ~3.3 kg"),
  40: WeekSize("🍉", "karpuz", "~51 cm · ~3.5 kg"),
};

WeekSize weekSizeFor(int week) {
  if (week < 4) return _sizes[4]!;
  if (week > 40) return _sizes[40]!;
  return _sizes[week] ?? _sizes[40]!;
}
