# Quarterly Theory EA — Dokumen Reka Bentuk

Tarikh: 2026-11-14 · Status: **Menunggu kelulusan**

Dokumen ini merekod semua keputusan dari sesi interview (grill-me, 3 pusingan).
Setiap peraturan di bawah ialah keputusan yang telah dipersetujui; perkara yang
belum diputuskan disenaraikan di bahagian **Keputusan Terbuka**.

## 1. Tujuan

EA scalping untuk MetaTrader 5 yang menukar model Quarterly Theory (AMDX + True
Open + SSMT) menjadi peraturan mekanikal. Fasa pertama: **backtest** untuk
membuktikan ada edge atau tidak. Live/prop firm hanya selepas backtest lulus.

- Platform: **MT5 / MQL5**
- Instrumen: **XAUUSD** dan **NDXUSD** (satu instance EA bagi setiap chart)
- Automasi: **auto penuh** (EA buka & tutup trade sendiri)

## 2. Masa (semua dalam waktu New York)

EA menukar masa server broker kepada waktu NY, termasuk DST AS (bermula Ahad
kedua Mac 02:00, tamat Ahad pertama November 02:00).

Mod penukaran (input `InpTimeMode`):
- `TIME_NY_PLUS_7` (default): server = NY + 7 jam sepanjang tahun. Ini standard
  kebanyakan broker forex (GMT+2/GMT+3 ikut DST AS).
- `TIME_MANUAL_GMT`: server = UTC + `InpServerGmtOffset` jam (tetap); EA kira DST
  NY sendiri.

Nota: `TimeGMT()` tidak boleh dipercayai dalam Strategy Tester, sebab itu offset
diambil dari input, bukan dari terminal.

### 2.1 Struktur kitaran

| Peringkat | Panjang | Pembahagian |
|---|---|---|
| Hari dagangan | 24 jam, bermula 18:00 NY (hari sebelumnya) | 4 sesi |
| Sesi | 6 jam | Asia 18:00–00:00 · London 00:00–06:00 · NY AM 06:00–12:00 · NY PM 12:00–18:00 |
| Kitaran 90 minit | 90 min | Q1–Q4 dalam setiap sesi (mula pada +0, +90, +180, +270 min) |
| Micro | 22.5 min (22 min 30 s) | Q1–Q4 dalam setiap kitaran 90 minit |

### 2.2 Tiga True Open (TO)

| TO | Masa | Harga |
|---|---|---|
| Daily TO | 00:00 NY | open bar M1 pada 00:00 |
| Session TO | mula sesi + 90 min (Asia 19:30, London 01:30, NY AM 07:30, NY PM 13:30) | open bar M1 pada masa itu |
| 90-min TO | mula kitaran 90 minit semasa + 22.5 min | open tick/bar pertama pada atau selepas masa itu |

TO yang belum terbentuk (contoh Daily TO semasa sesi Asia) **tidak dikira**.

## 3. Model Entry (versi 1)

Rangka: sesi 6 jam dibahagi kepada empat kuarter 90 minit (AMDX).

1. **Q1 (Accumulation)** — rekod `Q1High` dan `Q1Low` bagi simbol utama dan simbol pasangan.
2. **Q2 (Manipulation)** — SSMT mesti berlaku:
   - **SSMT bullish**: Q2 low simbol utama < Q1Low simbol utama **dan** Q2 low pasangan ≥ Q1Low pasangan.
   - **SSMT bearish**: Q2 high simbol utama > Q1High simbol utama **dan** Q2 high pasangan ≤ Q1High pasangan.
   - Jika simbol utama sweep **kedua-dua** belah dalam Q2, atau kedua-dua SSMT benar → tiada trade sesi itu.
   - `SweepExtreme` = low terendah Q2 (bullish) / high tertinggi Q2 (bearish).
3. **Penapis True Open** — buy hanya jika harga entry **di bawah** sekurang-kurangnya 2 TO yang telah terbentuk; sell hanya jika **di atas** sekurang-kurangnya 2 TO. Kurang daripada 2 TO terbentuk → tiada trade.
4. **Entry dalam Q3 (Distribution)** — pada M1: buy apabila bar M1 **tutup di atas** swing high fractal terakhir (2 bar kiri, 2 bar kanan) yang terbentuk selepas `SweepExtreme`; sell sebaliknya. Entry pada market, pada bar seterusnya.
   - Jika harga tembus `SweepExtreme` sebelum entry → setup batal.
5. **SL** = `SweepExtreme` ∓ buffer (`InpSLBufferPoints`, default 0 = guna spread semasa).
6. **TP** = RR **1:1** (jarak TP = jarak SL). Tiada breakeven, tiada trailing.
7. **Tutup paksa** — mana-mana posisi yang masih terbuka ditutup pada akhir Q4 (akhir sesi).

Setiap syarat (SSMT, penapis TO, MSS) mempunyai suis on/off untuk ujian kesan.

## 4. Risiko

| Peraturan | Nilai default |
|---|---|
| Risiko setiap trade | **$10** tetap (SL kena = −$10, TP kena = +$10) |
| Saiz lot | dikira dari jarak SL, **dibundarkan ke bawah** ke `SYMBOL_VOLUME_STEP` |
| Maks trade setiap kitaran 90 minit | 1 |
| Maks trade sehari setiap simbol | 3 |
| Had rugi harian | −$30 (realised, setiap simbol/magic) → berhenti sehingga 18:00 NY |

### 4.1 Perlindungan scalping — langkau trade jika:
- jarak SL < 3 × spread semasa
- spread > `InpMaxSpreadPoints`
- lot dikira < lot minimum broker
- lot dikira > `InpMaxLot`

## 5. Sesi

Keempat-empat sesi aktif secara default, masing-masing ada suis
(`InpTradeAsia`, `InpTradeLondon`, `InpTradeNYAM`, `InpTradeNYPM`).

## 6. Laporan

Pada `OnDeinit`, EA cetak dan tulis CSV (`QT_Report_<symbol>.csv` dalam
`MQL5/Files`) dengan statistik **per sesi**: bilangan trade, menang, kalah,
win rate, untung bersih. Setiap trade juga dilog (masa, sesi, arah, entry, SL,
TP, lot, sebab skip jika dilangkau).

## 7. Simbol & Pasangan SSMT

| Simbol utama | Pasangan SSMT | Fail preset |
|---|---|---|
| XAUUSD | XAGUSD | `presets/QT_XAUUSD.set` |
| NDXUSD | SPXUSD | `presets/QT_NDXUSD.set` |

Nama simbol ialah input (`InpPairSymbol`); broker belum ditentukan, jadi
nama pasangan perlu disahkan di Market Watch broker anda.

## 8. Backtest

- Tempoh: 2024-11-01 → 2026-11-01
- Model: *Every tick based on real ticks*
- Data: broker sendiri
- Baki permulaan: $1,000 USD
- Satu run bagi setiap simbol

## 9. Di luar skop versi 1
- Breakeven, trailing, partial close
- Weekly TO (pilihan untuk versi 2)
- Model fractal micro (lihat Keputusan Terbuka #1)
- Live trading / peraturan prop firm

## 10. Keputusan Terbuka

1. **Peringkat model untuk scalping.** Model di atas guna Q1–Q4 = kuarter 90 minit
   dalam sesi 6 jam (≈1 trade setiap sesi). Untuk scalping yang lebih kerap,
   model yang sama boleh dijalankan satu peringkat ke bawah: Q1–Q4 = micro 22.5
   minit dalam setiap kitaran 90 minit. **Default dalam pelan: peringkat sesi/90-min**,
   dengan input `InpModelLevel` supaya peringkat micro boleh diuji kemudian.
2. **Broker.** Nama simbol dan mod masa (NY+7 atau GMT manual) bergantung kepada broker.
3. **Had rugi harian** dikira bagi setiap instance (simbol). Jika mahu had untuk seluruh akaun, ia perlu diubah.
