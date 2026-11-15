# Keputusan Backtest & Protokol

## Protokol (dipersetujui 2026-11-15)
1. **Data pembangunan:** 2025.01.02 – 2025.12.31. Semua perubahan peraturan diputuskan atas data ini sahaja.
2. **Data ujian akhir:** 2026.01.01 – 2026.11.13. Dijalankan **sekali sahaja** selepas peraturan dikunci. Tiada perubahan selepas itu.
3. **Pasaran kedua:** model mesti juga diuji pada US100.s (pasangan US500.s).
4. **Demo 1–2 bulan** sebelum akaun live. Akaun live tidak disentuh sehingga keputusan demo sepadan dengan backtest.
5. Ujian guna deposit $1,000, risiko $10 (1%), mod *1 minute OHLC* (data tick hanya dari 2026.09.30).

## Keputusan setakat ini — XAUUSD.s, 2025.01.02 – 2026.11.13

| Versi | Trade | TP / SL / masa | Bersih | PF | Nota |
|---|---|---|---|---|---|
| RR 1:1, tutup akhir Q4, SL ≥ 3×spread | 53 | 16 / 27 / 10 | −$104 | ~0.5 | |
| RR 1:2, tiada tutup Q4, SL ≥ 10×spread | 52 | 12 / 30 / 10 | −$26 | 0.89 | 2025: −$62, 2026: +$36 |
| Sama, akaun $100, risiko $2 | 12 | — | +$5.97 | 1.49 | sampel terlalu kecil |

RR 1:2 ikut sesi: London −$29 (4 TP / 13 SL), NY AM −$3, NY PM +$2, Asia +$3 (3 trade).
Pulang modal RR 1:2 memerlukan ≥ 33% kena TP; keputusan: 29%.

Logik EA disahkan (baris `detail` disemak manual: masa NY, SSMT, True Open betul).

## Ujian seterusnya (data pembangunan 2025 sahaja)
| # | Preset | Perubahan | Hipotesis |
|---|---|---|---|
| 1 | QT_XAUUSD.set | InpTradeLondon=false | London ialah sesi lemah |
| 2 | QT_US100.set | — | model berfungsi di pasaran lain |

## Keputusan ujian data pembangunan (2025)

| # | Ujian | Trade | TP / SL / masa | Bersih | PF | Keputusan |
|---|---|---|---|---|---|---|
| 1 | XAUUSD.s, London off | 28 | 6 / 15 / 7 | −$3.36 | 0.97 | **Gagal** — hipotesis London tidak menghasilkan edge; kadar TP 29% < 33% |
| 2 | US100.s | 0 | — | $0 | — | **Tidak sah** — 0 trade; punca perlu disiasat (log Agent) |

Ujian 1 ikut sesi: NY AM 11 trade (3 TP / 8 SL) −$18.47; NY PM 15 trade (2 TP / 6 SL / 7 masa) +$6.34 (untung datang dari tutup ikut masa, bukan TP); Asia 2 trade +$8.77.

## Strategi kedua: QT + Bollinger Bands (`QT_BB_EA.mq5`) — belum diuji
- Isyarat: bar M5 tutup di luar Bollinger Band (20, 2.0), bar seterusnya tutup semula di dalam → masuk melawan arah (mean reversion).
- Penapis Quarterly Theory: buy hanya di bawah ≥ 2 True Open, sell hanya di atas ≥ 2 True Open.
- Lot tetap 0.01, SL = $5.00 dari entry, TP = $5.00 (1:1). Maks 1 trade setiap kitaran 90 minit, 5 sehari, had rugi harian $15.
- Preset: `presets/QT_BB_XAUUSD_100.set`. Protokol sama: bangunkan atas 2025, 2026 sebagai ujian akhir.

### QT + BB, XAUUSD.s M5, deposit $100, risiko $5 (1:1) — 2025
| Trade | TP / SL / masa | Bersih | PF | Nota |
|---|---|---|---|---|
| 104 | 41 / 60 / 3 | −$100.35 | 0.67 | **Akaun habis pada 2025.02.03** — hanya ~1 bulan diuji |

Ikut sesi: NY AM 8 TP / 26 SL (−$90); London 21 / 20 (+$5); Asia 12 / 12 (−$3); NY PM −$12.
Ikut arah: buy +$21.80, sell −$122.15 (emas dalam uptrend kuat Jan 2025; sell melawan trend rugi).
Kadar TP 41% vs ~53% diperlukan untuk RR 1:1.

### QT + BB, XAUUSD.s M5, deposit $1,000, risiko $5 (1:1) — 2025 penuh
| Trade | TP / SL / masa | Bersih | PF | Drawdown maks |
|---|---|---|---|---|
| 1210 | 604 / 596 / 10 | +$47.69 | 1.02 | $150 (14.9%) |

Kadar TP 50.3% (ralat piawai ±1.4%) — tidak dapat dibezakan daripada lambungan syiling.
Buy: +$189 (53% TP); sell: −$141 (48% TP). Emas naik dari ~2650 ke ~4500 pada 2025, jadi kelebihan buy ialah trend pasaran, bukan strategi.
Ikut sesi: London +$140, Asia −$25, NY AM −$80, NY PM +$13. 7 bulan untung, 5 bulan rugi.
Drawdown $150 melebihi akaun $100 — sebab itu ujian $100 habis dalam sebulan.

### QT + BB — UJIAN AKHIR 2026 (2026.01.01 – 2026.11.13), tiada perubahan setting
| Trade | TP / SL | Bersih | PF | Drawdown maks |
|---|---|---|---|---|
| 1044 | 506 / 538 | −$160.00 | 0.94 | $295 (27.3%) |

Kadar TP 48.5%. 3 bulan untung, 8 bulan rugi. London, sesi terbaik 2025 (+$140), jadi sesi terburuk 2026 (−$140). Buy −$110, sell −$50.

**Keputusan: strategi QT + BB DITUTUP.** Tiada edge; hasil 2025 (+$47) ialah kebetulan/trend emas.

## Status projek (2026-11-15)
- Tiada strategi yang diuji menunjukkan edge. Tiada EA yang disyorkan untuk akaun live.
- Langkah seterusnya: trade manual di akaun demo, ≥ 30 trade, guna `docs/JURNAL-MANUAL.md`; kemudian kodkan peraturan yang terbukti.
