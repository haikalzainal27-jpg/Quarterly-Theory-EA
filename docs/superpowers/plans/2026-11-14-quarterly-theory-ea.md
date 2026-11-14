# Quarterly Theory EA — Pelan Pelaksanaan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** EA scalping MT5 yang trade XAUUSD dan NDXUSD dengan model Quarterly Theory (AMDX 90-min + 3 True Open + SSMT + MSS M1), RR 1:1, risiko $10 tetap, sedia untuk backtest.

**Architecture:** Semua logik dagangan ditulis sebagai fungsi tulen (pure) dalam fail `.mqh` yang menerima data (masa, array `MqlRates`, nombor) dan memulangkan keputusan. Ia tidak memanggil API terminal, jadi boleh diuji oleh skrip ujian. Hanya `QT_Data.mqh` (ambil data) dan `QT_Trade.mqh` (hantar order) yang menyentuh terminal. EA (`QT_EA.mq5`) berjalan pada setiap bar M1 baru.

**Tech Stack:** MQL5 (MetaTrader 5 build ≥ 4000), MetaEditor, Strategy Tester. Tiada library luar; guna `<Trade/Trade.mqh>` standard.

**Spec:** `docs/superpowers/specs/2026-11-14-quarterly-theory-ea-design.md`

## Global Constraints

- Semua masa logik dalam waktu **New York**; penukaran hanya melalui `QT_ServerToNY()` / `QT_NYToServer()`.
- Hari dagangan bermula **18:00 NY**. Sesi: Asia 18–00, London 00–06, NY AM 06–12, NY PM 12–18.
- Kitaran 90 minit = 5400 s; micro = 1350 s (22.5 min).
- Risiko tetap `InpRiskUSD = 10.0`; RR `1:1`; lot **dibundarkan ke bawah**.
- `InpMaxTradesPerDay = 3`, `InpMaxTradesPerCycle = 1`, `InpDailyLossUSD = 30.0`.
- Skip jika SL < `InpMinSLSpreadMult = 3.0` × spread, spread > `InpMaxSpreadPoints`, lot < min, lot > `InpMaxLot`.
- Fractal = 2 bar kiri + 2 bar kanan pada M1.
- Prefix nama fail/fungsi: `QT_`. Magic number default `20261114`.
- Ujian dijalankan sebagai skrip MT5 (`QT_Tests.mq5`); kriteria lulus: log Experts mencetak `QT TESTS: <n> passed, 0 failed`.
- MQL5 tidak boleh di-compile dalam container Linux ini; langkah "compile" dan "run" dibuat oleh pengguna dalam MetaEditor/MT5 (Windows), atau pada mesin dengan MT5 + Wine.

## Review Focus

1. **Minggu pertukaran DST** (Mac & Nov): server NY+7 kekal betul, tetapi mod `TIME_MANUAL_GMT` mesti beralih tepat pada 02:00 NY → ujian dalam Task 2.
2. **Daily TO belum terbentuk dalam sesi Asia**: penapis mesti kira 2 daripada TO yang wujud sahaja, bukan anggap 0 → ujian dalam Task 3.
3. **Bar M1 hilang / pasaran tutup** (NDX tutup harian 17:00–18:00 NY, hujung minggu, cuti): julat kuarter dengan 0 bar mesti ditanda tidak sah, bukan high=0/low=0 → ujian dalam Task 4.
4. **Simbol utama sweep kedua-dua belah dalam Q2**: mesti `SSMT_NONE` → ujian dalam Task 5.
5. **Lot terlalu kecil untuk risiko $10** (SL lebar pada NDX): mesti skip, tidak dibundarkan ke atas ke 0.01 → ujian dalam Task 7.

---

## Struktur Fail

```
MQL5/
  Experts/QuarterlyTheory/QT_EA.mq5          # EA utama: inputs, OnInit/OnTick/OnDeinit
  Include/QuarterlyTheory/
    QT_Types.mqh       # enum & struct dikongsi
    QT_Time.mqh        # server↔NY, DST, kedudukan dalam kitaran
    QT_TrueOpen.mqh    # masa & harga 3 TO, penapis TO
    QT_Ranges.mqh      # high/low kuarter dari array MqlRates
    QT_SSMT.mqh        # pengesanan SSMT
    QT_Structure.mqh   # fractal & MSS M1
    QT_Risk.mqh        # kiraan lot, penapis scalping, had harian
    QT_Signal.mqh      # gabung semua → QTSignal
    QT_Data.mqh        # CopyRates/SymbolInfo (sentuh terminal)
    QT_Trade.mqh       # CTrade, tutup paksa (sentuh terminal)
    QT_Report.mqh      # statistik per sesi + CSV
    QT_TestLib.mqh     # assert helpers
  Scripts/QuarterlyTheory/QT_Tests.mq5        # semua unit test
presets/QT_XAUUSD.set, presets/QT_NDXUSD.set
docs/BACKTEST.md
```

---

### Task 1: Scaffolding, jenis data & rangka ujian

**Files:**
- Create: `MQL5/Include/QuarterlyTheory/QT_Types.mqh`, `QT_TestLib.mqh`, `MQL5/Scripts/QuarterlyTheory/QT_Tests.mq5`, `README.md`, `.gitignore`

**Interfaces:**
- Produces:
  - `enum QTSession { QT_ASIA=0, QT_LONDON=1, QT_NYAM=2, QT_NYPM=3 };`
  - `enum QTTimeMode { TIME_NY_PLUS_7, TIME_MANUAL_GMT };`
  - `enum QTModelLevel { MODEL_SESSION_90M, MODEL_CYCLE_MICRO };`
  - `enum QTDir { DIR_NONE=0, DIR_BUY=1, DIR_SELL=-1 };`
  - `struct QTRange { bool valid; double high; double low; datetime highTime; datetime lowTime; };`
  - `struct QTCyclePos { datetime nyTime; datetime tradingDayStartNY; QTSession session; int cycle90Idx; int microIdx; datetime frameStartNY; int frameQuarter; int frameQuarterSec; };` — `frameQuarter` 0..3 ialah kuarter dalam rangka model (sesi bagi `MODEL_SESSION_90M`, kitaran 90-min bagi `MODEL_CYCLE_MICRO`).
  - `QT_TestLib.mqh`: `void QT_AssertTrue(bool c, string name)`, `void QT_AssertEqInt(long exp, long act, string name)`, `void QT_AssertEqDbl(double exp, double act, double eps, string name)`, `void QT_TestSummary()` — mencetak `QT TESTS: <p> passed, <f> failed`.

- [ ] **Step 1:** Tulis `QT_Tests.mq5` dengan satu ujian `Test_Harness()` yang memanggil `QT_AssertTrue(true,"harness")` dan `QT_TestSummary()` dalam `OnStart`.
- [ ] **Step 2:** Compile (F7) dalam MetaEditor → 0 error; jalankan skrip → log: `QT TESTS: 1 passed, 0 failed`.
- [ ] **Step 3:** Tambah `README.md` (cara salin folder `MQL5/` ke Data Folder MT5, compile, jalankan ujian) dan `.gitignore` (`*.ex5`, `*.log`).
- [ ] **Step 4:** Commit `chore: scaffold project, types and test harness`.

---

### Task 2: Masa NY & kedudukan kitaran (`QT_Time.mqh`)

**Interfaces:**
- Consumes: `QTTimeMode`, `QTCyclePos`, `QTModelLevel`.
- Produces:
  - `bool QT_IsUSDST(datetime utc)` — benar antara Ahad ke-2 Mac 07:00 UTC dan Ahad pertama Nov 06:00 UTC.
  - `datetime QT_ServerToNY(datetime server, QTTimeMode mode, int gmtOffsetHours)`
  - `datetime QT_NYToServer(datetime ny, QTTimeMode mode, int gmtOffsetHours)`
  - `QTCyclePos QT_GetCyclePos(datetime ny, QTModelLevel level)`

- [ ] **Step 1: Ujian gagal** dalam `QT_Tests.mq5`:
  - `QT_IsUSDST(D'2026.03.08 06:59')==false`, `QT_IsUSDST(D'2026.03.08 07:00')==true`, `QT_IsUSDST(D'2026.11.01 05:59')==true`, `QT_IsUSDST(D'2026.11.01 06:00')==false`.
  - `QT_ServerToNY(D'2026.06.10 16:30', TIME_NY_PLUS_7, 0) == D'2026.06.10 09:30'`.
  - `QT_ServerToNY(D'2026.06.10 13:30', TIME_MANUAL_GMT, 0) == D'2026.06.10 09:30'` (EDT, UTC−4); `QT_ServerToNY(D'2026.01.10 14:30', TIME_MANUAL_GMT, 0) == D'2026.01.10 09:30'` (EST).
  - Round-trip `QT_NYToServer(QT_ServerToNY(t))==t` untuk kedua-dua mod.
  - `QT_GetCyclePos(D'2026.06.10 09:30', MODEL_SESSION_90M)`: `session==QT_NYAM`, `cycle90Idx==2`, `microIdx==1`, `frameQuarter==2`, `frameStartNY==D'2026.06.10 06:00'`.
  - `QT_GetCyclePos(D'2026.06.10 19:00', ...)`: `session==QT_ASIA`, `tradingDayStartNY==D'2026.06.10 18:00'`; pada `D'2026.06.10 17:59'` → `tradingDayStartNY==D'2026.06.09 18:00'`.
  - `MODEL_CYCLE_MICRO` pada `09:30` → `frameStartNY==09:00`, `frameQuarter==1`.
- [ ] **Step 2:** Jalankan → gagal (fungsi belum wujud / compile error).
- [ ] **Step 3:** Laksanakan. Untuk mod manual: `utc = server − offset*3600`; `ny = utc − (QT_IsUSDST(utc)?4:5)*3600`. `QT_NYToServer` mod manual: cuba EDT dahulu, sahkan dengan `QT_IsUSDST`, jika tidak guna EST.
- [ ] **Step 4:** Jalankan → semua lulus.
- [ ] **Step 5:** Commit `feat: NY time conversion and cycle position`.

---

### Task 3: True Open (`QT_TrueOpen.mqh`)

**Interfaces:**
- Consumes: `QTCyclePos`.
- Produces:
  - `void QT_TrueOpenTimesNY(const QTCyclePos &p, datetime &dailyTO, datetime &sessionTO, datetime &cycleTO)` — daily = `tradingDayStartNY + 6h` (00:00); session = mula sesi + 5400 s; cycle = mula kitaran 90-min + 1350 s.
  - `int QT_TrueOpenVotes(QTDir dir, double price, const double &toPrices[], const bool &toFormed[])` — bilangan TO yang terbentuk dan bersetuju (buy: `price < to`; sell: `price > to`).
  - `bool QT_TrueOpenPass(QTDir dir, double price, const double &toPrices[], const bool &toFormed[], int minVotes=2)`

- [ ] **Step 1: Ujian gagal:**
  - Untuk `09:30 NY`: dailyTO `00:00`, sessionTO `07:30`, cycleTO `09:22:30`.
  - Untuk `19:00 NY` (Asia): dailyTO = `00:00` hari berikutnya (masa depan → tidak terbentuk), sessionTO `19:30`.
  - Votes: buy, price 100, TO {101,102,99} semua formed → 2 → pass.
  - Buy, price 100, TO {101,0,0}, formed {true,false,false} → 1 → **fail** (Review Focus #2).
  - Sell, price 100, TO {99,98,101} → 2 → pass.
- [ ] **Step 2:** Jalankan → gagal.
- [ ] **Step 3:** Laksanakan.
- [ ] **Step 4:** Jalankan → lulus.
- [ ] **Step 5:** Commit `feat: true open times and filter`.

---

### Task 4: Julat kuarter (`QT_Ranges.mqh`)

**Interfaces:**
- Consumes: `QTRange`.
- Produces: `QTRange QT_RangeBetween(const MqlRates &rates[], datetime fromServer, datetime toServerExclusive)` — high/low semua bar M1 dengan `time` dalam `[from, to)`; `valid=false` jika 0 bar.

- [ ] **Step 1: Ujian gagal:** bina array 6 bar M1 sintetik; julat 3 bar tengah memberi high/low dan `highTime/lowTime` yang betul; julat tanpa bar → `valid==false` (Review Focus #3); sempadan `to` adalah eksklusif.
- [ ] **Step 2:** Jalankan → gagal.
- [ ] **Step 3:** Laksanakan (array tidak bergantung kepada `ArraySetAsSeries`; iterasi penuh).
- [ ] **Step 4:** Jalankan → lulus.
- [ ] **Step 5:** Commit `feat: quarter range extraction`.

---

### Task 5: SSMT (`QT_SSMT.mqh`)

**Interfaces:**
- Consumes: `QTRange`, `QTDir`.
- Produces: `QTDir QT_DetectSSMT(const QTRange &mainQ1, const QTRange &mainQ2, const QTRange &pairQ1, const QTRange &pairQ2)`

- [ ] **Step 1: Ujian gagal:**
  - main Q2.low < Q1.low, pair Q2.low ≥ Q1.low, main tidak sweep high → `DIR_BUY`.
  - main Q2.high > Q1.high, pair Q2.high ≤ Q1.high → `DIR_SELL`.
  - kedua-dua simbol sweep low → `DIR_NONE`.
  - main sweep high **dan** low → `DIR_NONE` (Review Focus #4).
  - mana-mana julat `valid==false` → `DIR_NONE`.
- [ ] **Step 2:** Jalankan → gagal.
- [ ] **Step 3:** Laksanakan.
- [ ] **Step 4:** Jalankan → lulus.
- [ ] **Step 5:** Commit `feat: SSMT detection`.

---

### Task 6: Fractal & MSS M1 (`QT_Structure.mqh`)

**Interfaces:**
- Produces:
  - `bool QT_IsFractalHigh(const MqlRates &r[], int i)` / `QT_IsFractalLow` — `r` tersusun lama→baru; perlu 2 bar kiri dan 2 kanan, ketat (`>`/`<`).
  - `bool QT_DetectMSS(const MqlRates &r[], QTDir dir, datetime afterTime, double &brokenLevel)` — benar jika bar **terakhir yang tutup** (`r[n-1]`) close melepasi fractal (buy: high; sell: low) terkini yang terbentuk selepas `afterTime` dan sebelum bar itu; `brokenLevel` = paras fractal tersebut. Hanya bar pertama yang menembusi dikira (bar sebelumnya belum tutup melepasinya).

- [ ] **Step 1: Ujian gagal:** siri sintetik dengan swing high pada indeks 5; bar 9 tutup di atasnya → `true`, `brokenLevel` = high bar 5; bar 10 juga di atas → `false` (bukan penembusan pertama); fractal sebelum `afterTime` diabaikan; versi sell simetri.
- [ ] **Step 2:** Jalankan → gagal.
- [ ] **Step 3:** Laksanakan.
- [ ] **Step 4:** Jalankan → lulus.
- [ ] **Step 5:** Commit `feat: M1 fractal and market structure shift`.

---

### Task 7: Risiko (`QT_Risk.mqh`)

**Interfaces:**
- Produces:
  - `double QT_CalcLot(double riskUSD, double slDistPrice, double tickValue, double tickSize, double volMin, double volStep)` — `lot = riskUSD / (slDistPrice/tickSize*tickValue)`, bundar **ke bawah** ke `volStep`; pulangkan 0 jika < `volMin`.
  - `enum QTSkip { SKIP_NONE, SKIP_SL_TOO_SMALL, SKIP_SPREAD, SKIP_LOT_MIN, SKIP_LOT_MAX, SKIP_DAILY_LOSS, SKIP_MAX_DAY, SKIP_MAX_CYCLE, SKIP_TO_FILTER, SKIP_SESSION_OFF };`
  - `QTSkip QT_CheckScalpFilters(double slDistPoints, double spreadPoints, double lot, double minSLSpreadMult, double maxSpreadPoints, double maxLot)`
  - `QTSkip QT_CheckDailyLimits(double realisedTodayUSD, int tradesToday, int tradesThisCycle, double dailyLossUSD, int maxPerDay, int maxPerCycle)`
  - `string QT_SkipName(QTSkip s)`

- [ ] **Step 1: Ujian gagal:**
  - XAU: risk 10, SL 2.00, tickValue 1.0, tickSize 0.01, volMin 0.01, step 0.01 → `0.05`.
  - Bundar ke bawah: hasil mentah 0.0599 → `0.05`.
  - NDX: risk 10, SL 150.0, tickValue 0.01, tickSize 0.01, volMin 0.1, step 0.1 → mentah 0.0667 → `0` (Review Focus #5); `QT_CheckScalpFilters(..., lot=0, ...)` → `SKIP_LOT_MIN`.
  - SL 20 pts, spread 8 pts, mult 3 → `SKIP_SL_TOO_SMALL`; spread > max → `SKIP_SPREAD`; lot > maxLot → `SKIP_LOT_MAX`.
  - realised −30 → `SKIP_DAILY_LOSS`; tradesToday 3 → `SKIP_MAX_DAY`; tradesThisCycle 1 → `SKIP_MAX_CYCLE`; −29.99, 2, 0 → `SKIP_NONE`.
- [ ] **Step 2:** Jalankan → gagal.
- [ ] **Step 3:** Laksanakan (guna `MathFloor(raw/step + 1e-9)*step` dan `NormalizeDouble`).
- [ ] **Step 4:** Jalankan → lulus.
- [ ] **Step 5:** Commit `feat: fixed-dollar lot sizing and scalping filters`.

---

### Task 8: Penjana isyarat (`QT_Signal.mqh`)

**Interfaces:**
- Consumes: semua fungsi Task 2–7.
- Produces:
  - `struct QTSignalInput { QTCyclePos pos; QTRange mainQ1, mainQ2, pairQ1, pairQ2; double toPrices[3]; bool toFormed[3]; double bid, ask, point; bool useSSMT, useTO, useMSS; };` (+ array M1 utama dihantar berasingan)
  - `struct QTSignal { QTDir dir; double entry, sl, tp; double sweepExtreme; QTSkip skip; string reason; };`
  - `QTSignal QT_BuildSignal(const QTSignalInput &in, const MqlRates &m1[], double slBufferPrice)`

Logik: hanya bila `pos.frameQuarter==2` (Q3). Arah dari SSMT (atau, jika `useSSMT=false`, dari sisi yang di-sweep dalam Q2). Batal jika harga semasa telah melepasi `sweepExtreme`. MSS selepas masa `sweepExtreme`. Entry = ask (buy) / bid (sell); SL = `sweepExtreme ∓ buffer`; TP = entry ± |entry − SL|.

- [ ] **Step 1: Ujian gagal:** senario buy lengkap sintetik → `dir==DIR_BUY`, `tp-entry == entry-sl` (eps 1e-9); `frameQuarter==1` → `DIR_NONE`; harga di bawah `sweepExtreme` → `DIR_NONE` dengan reason `"invalidated"`; TO gagal → `skip==SKIP_TO_FILTER`; `useMSS=false` → entry tanpa MSS.
- [ ] **Step 2:** Jalankan → gagal.
- [ ] **Step 3:** Laksanakan.
- [ ] **Step 4:** Jalankan → lulus.
- [ ] **Step 5:** Commit `feat: signal builder combining AMDX, SSMT, TO and MSS`.

---

### Task 9: Data, dagangan & EA utama

**Files:**
- Create: `QT_Data.mqh`, `QT_Trade.mqh`, `MQL5/Experts/QuarterlyTheory/QT_EA.mq5`

**Interfaces:**
- `QT_Data.mqh`: `bool QT_LoadM1(string sym, datetime fromServer, datetime toServer, MqlRates &out[])` (guna `CopyRates`, susunan lama→baru; untuk simbol pasangan, panggil `SymbolSelect(sym,true)` dalam `OnInit`); `double QT_PriceAt(string sym, datetime server)` — open bar M1 pertama ≥ masa itu, 0 jika tiada.
- `QT_Trade.mqh`: `bool QT_Open(QTSignal &s, double lot, long magic, string comment)`; `void QT_CloseAll(string sym, long magic)`; `double QT_RealisedSince(string sym, long magic, datetime fromServer)`; `int QT_DealsSince(...)`.
- `QT_EA.mq5` inputs (default): `InpTimeMode=TIME_NY_PLUS_7`, `InpServerGmtOffset=2`, `InpModelLevel=MODEL_SESSION_90M`, `InpPairSymbol="XAGUSD"`, `InpRiskUSD=10`, `InpDailyLossUSD=30`, `InpMaxTradesPerDay=3`, `InpMaxTradesPerCycle=1`, `InpMaxSpreadPoints=50`, `InpMinSLSpreadMult=3.0`, `InpMaxLot=5.0`, `InpSLBufferPoints=0`, `InpUseSSMT=true`, `InpUseTO=true`, `InpUseMSS=true`, `InpTradeAsia/London/NYAM/NYPM=true`, `InpMagic=20261114`.

Aliran `OnTick`: proses hanya pada bar M1 baru → kira `QTCyclePos` → jika masa ≥ akhir rangka dan ada posisi → `QT_CloseAll` → semak suis sesi & had harian → muat M1 utama & pasangan untuk rangka semasa → bina `QTSignalInput` → `QT_BuildSignal` → kira lot → penapis scalping → `QT_Open` dengan komen `QT|<session>|<cycle90Idx>` → log setiap skip.

- [ ] **Step 1:** Compile EA → 0 error, 0 warning.
- [ ] **Step 2:** Strategy Tester, XAUUSD M1, 1 minggu (2026-06-08 → 2026-06-13), *visual mode*: sahkan secara manual sekurang-kurangnya 2 trade — sweep Q2, SSMT dengan XAG, MSS M1 dalam Q3, SL/TP 1:1, lot memberi ≈ $10 risiko. Rekod tangkapan skrin dalam `docs/verification/`.
- [ ] **Step 3:** Sahkan tutup paksa: cari trade yang masih terbuka di akhir sesi → ditutup pada bar pertama selepas akhir Q4.
- [ ] **Step 4:** Commit `feat: EA wiring, data loading and order execution`.

---

### Task 10: Laporan per sesi, preset & panduan backtest

**Files:**
- Create: `QT_Report.mqh`, `presets/QT_XAUUSD.set`, `presets/QT_NDXUSD.set`, `docs/BACKTEST.md`

**Interfaces:**
- `void QT_ReportBuild(string sym, long magic, datetime fromServer, string fileName)` — baca sejarah deal, kumpul ikut tag sesi dari komen, tulis CSV `session,trades,wins,losses,winrate,net_usd` + baris `TOTAL`, dan `Print` jadual yang sama.

- [ ] **Step 1: Ujian gagal** (dalam `QT_Tests.mq5`) untuk fungsi tulen `QT_SessionFromComment("QT|NYAM|2")==QT_NYAM`, dan agregasi `QT_AggregateStats` atas array deal sintetik (3 menang +10, 2 kalah −10 → net 10, winrate 60.0).
- [ ] **Step 2:** Jalankan → gagal. **Step 3:** Laksanakan. **Step 4:** Lulus.
- [ ] **Step 5:** Tulis preset: XAUUSD (`InpPairSymbol=XAGUSD`, `InpMaxSpreadPoints=50`), NDXUSD (`InpPairSymbol=SPXUSD`, `InpMaxSpreadPoints=200`, `InpTradeAsia=false`).
- [ ] **Step 6:** `docs/BACKTEST.md`: tetapan tester (2024-11-01 → 2026-11-01, Every tick based on real ticks, deposit 1000 USD, leverage broker), cara muat preset, cara baca CSV, dan senarai semak "edge": PF > 1.2, ≥ 200 trade, win rate > 55% (RR 1:1 perlu > 50% + kos).
- [ ] **Step 7:** Commit `feat: per-session report, presets and backtest guide`.

---

### Task 11: Backtest penuh & keputusan

- [ ] **Step 1:** Jalankan backtest 2 tahun untuk XAUUSD dan NDXUSD mengikut `docs/BACKTEST.md`.
- [ ] **Step 2:** Simpan laporan HTML tester + CSV ke `docs/results/2026-11-<simbol>/`.
- [ ] **Step 3:** Jalankan semula dengan setiap suis dimatikan satu demi satu (`InpUseSSMT`, `InpUseTO`, `InpUseMSS`) untuk ukur sumbangan setiap komponen; rekod jadual perbandingan dalam `docs/results/SUMMARY.md`.
- [ ] **Step 4:** Commit `docs: v1 backtest results`. Keputusan teruskan / ubah model (contoh: cuba `MODEL_CYCLE_MICRO`) dibuat bersama pengguna.
