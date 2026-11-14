# Quarterly Theory EA (MT5)

EA scalping MetaTrader 5 berasaskan Quarterly Theory: AMDX kitaran 90 minit, 3 True Open, SSMT dan MSS M1. RR 1:1, risiko $10 tetap. Simbol: XAUUSD dan NDXUSD.

- Reka bentuk: `docs/superpowers/specs/2026-11-14-quarterly-theory-ea-design.md`
- Pelan pelaksanaan: `docs/superpowers/plans/2026-11-14-quarterly-theory-ea.md`

## Skill Claude Code
`.claude/skills/` mengandungi:
- `grill-me` / `grilling` dari [mattpocock/skills](https://github.com/mattpocock/skills)
- skill `superpowers` dari [obra/superpowers](https://github.com/obra/superpowers)

Kedua-duanya berlesen MIT; lihat `third_party/`.

## Mula
Lihat `docs/BACKTEST.md` untuk cara pasang, jalankan ujian unit, dan backtest.

## Struktur
- `MQL5/Experts/QuarterlyTheory/QT_EA.mq5` — EA
- `MQL5/Include/QuarterlyTheory/*.mqh` — logik (masa NY, True Open, julat, SSMT, MSS, risiko, isyarat, laporan)
- `MQL5/Scripts/QuarterlyTheory/QT_Tests.mq5` — ujian unit
- `presets/` — tetapan input untuk XAUUSD dan NDXUSD

Status: v1 ditulis, menunggu compile & backtest dalam MT5.
