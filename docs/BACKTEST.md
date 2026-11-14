# Panduan Pemasangan & Backtest

## 1. Pasang
1. MT5 → **File → Open Data Folder**.
2. Salin folder `MQL5/` dari repo ini ke dalam Data Folder (gabungkan dengan folder `MQL5` sedia ada).
3. Buka MetaEditor (F4). Compile (F7):
   - `Scripts/QuarterlyTheory/QT_Tests.mq5`
   - `Experts/QuarterlyTheory/QT_EA.mq5`
   Kedua-duanya mesti 0 error.

## 2. Jalankan ujian unit
Dalam MT5, seret skrip **QT_Tests** ke mana-mana chart. Tab **Experts** mesti menunjukkan:
```
QT TESTS: <n> passed, 0 failed
```
Jika ada `FAIL: ...`, salin baris itu dan hantar kepada Claude.

## 3. Sahkan broker (Versus Trade)
- **Masa server:** Market Watch menunjukkan masa server. Pada waktu musim panas AS (Mac–Nov), server mestilah 7 jam di hadapan New York. Contohnya 09:30 NY = 16:30 server. Jika betul, kekalkan `InpTimeMode=TIME_NY_PLUS_7`. Jika tidak, guna `TIME_MANUAL_GMT` dan isi `InpServerGmtOffset`.
- **Nama simbol:** pastikan `XAUUSD`, `XAGUSD`, `NDXUSD` dan pasangan indeks S&P 500 wujud. Kalau nama S&P 500 lain (contohnya `US500` atau `SPX500`), ubah `InpPairSymbol` dalam `presets/QT_NDXUSD.set`.

## 4. Tetapan Strategy Tester
| Tetapan | Nilai |
|---|---|
| Expert | QuarterlyTheory\QT_EA |
| Simbol | XAUUSD (kemudian NDXUSD) |
| Timeframe | M1 |
| Tarikh | 2024.11.01 – 2026.11.01 |
| Modelling | Every tick based on real ticks |
| Deposit | 1000 USD |
| Inputs | Load → `presets/QT_<simbol>.set` |

Ujian visual ringkas dulu (1 minggu, contohnya 2026.06.08–2026.06.13, *Visual mode*) untuk sahkan dengan mata:
- Ada sweep dalam Q2.
- Simbol pasangan tidak sweep (SSMT).
- Ada MSS di M1 dalam Q3.
- SL/TP 1:1, dan risiko ≈ $10.

## 5. Baca keputusan
- Tab **Journal/Experts**: setiap setup log sebab skip (`no_ssmt`, `no_mss`, `to_filter`, `skip SPREAD` ...).
- Pada akhir ujian: jadual `=== QT REPORT ===` dan fail `QT_Report_<simbol>.csv`. Fail ini berada di `Tester/<agent>/MQL5/Files` dalam Data Folder.

## 6. Senarai semak "ada edge?"
- ≥ 200 trade
- Win rate > 55% (RR 1:1 perlu > 50% + kos spread/komisen)
- Profit Factor > 1.2
- Drawdown maksimum boleh diterima
- Keputusan konsisten antara sesi. Lihat CSV per sesi; sesi yang rugi boleh dimatikan.

## 7. Ujian komponen
Ulang backtest dengan setiap suis ini dimatikan satu demi satu: `InpUseSSMT`, `InpUseTO`, `InpUseMSS`. Rekod perbandingan dalam `docs/results/SUMMARY.md`. Selepas itu cuba juga `InpModelLevel=MODEL_CYCLE_MICRO` untuk scalping yang lebih kerap.
