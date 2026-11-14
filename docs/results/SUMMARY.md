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
