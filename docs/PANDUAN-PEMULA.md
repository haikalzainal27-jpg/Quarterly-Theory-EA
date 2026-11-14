# Panduan Pemula: Uji Quarterly Theory EA dari Kosong

Panduan ini untuk komputer **Windows**. Ikut langkah satu demi satu. Jangan langkau.

---

## Bahagian A — Pasang MT5 dan buka akaun demo

1. Log masuk ke portal klien **Versus Trade** dan muat turun **MetaTrader 5 (MT5)** untuk Windows.
2. Jalankan fail installer, tekan **Next** sehingga selesai. MT5 akan dibuka sendiri.
3. Buka akaun **DEMO**. Jangan guna akaun live untuk ujian.
   - Dalam MT5: **File → Open an Account**, pilih server Versus Trade, kemudian pilih *demo*.
   - Atau log masuk akaun demo yang sudah dibuat di portal: **File → Login to Trade Account**.
4. Pastikan sudut kanan bawah MT5 menunjukkan sambungan (ada angka seperti `123/4 kb`, bukan "No connection").

---

## Bahagian B — Dapatkan fail EA

1. Muat turun `Quarterly-Theory-EA.zip`, dari fail yang Claude berikan atau dari GitHub (butang **Code → Download ZIP**).
2. Klik kanan zip, pilih **Extract All…**, kemudian **Extract**.
3. Dalam folder yang di-extract, anda akan nampak folder `MQL5`, `presets` dan `docs`.

---

## Bahagian C — Salin fail ke dalam MT5

1. Dalam MT5, klik menu **File → Open Data Folder**. Satu tetingkap Windows Explorer akan terbuka.
2. Buka folder **MQL5** dalam tetingkap itu. Biarkan tetingkap ini terbuka.
3. Dalam folder zip yang di-extract, buka folder `MQL5`. Salin:

   | Dari zip | Tampal ke Data Folder |
   |---|---|
   | `MQL5\Experts\QuarterlyTheory` | `MQL5\Experts\` |
   | `MQL5\Include\QuarterlyTheory` | `MQL5\Include\` |
   | `MQL5\Scripts\QuarterlyTheory` | `MQL5\Scripts\` |
   | fail dalam `presets\` (`QT_XAUUSD.set`, `QT_NDXUSD.set`) | `MQL5\Profiles\Tester\` |

   Tip: salin **folder** `QuarterlyTheory`, bukan fail di dalamnya satu per satu.

---

## Bahagian D — Compile dalam MetaEditor

"Compile" ialah proses menukar kod (`.mq5`) kepada program yang MT5 boleh jalankan (`.ex5`).

1. Dalam MT5 tekan **F4**, atau klik ikon **IDE** di toolbar. **MetaEditor** akan dibuka.
2. Di panel kiri (**Navigator**), kembangkan **Scripts → QuarterlyTheory**, kemudian double-click **QT_Tests.mq5**.
   - Jika panel Navigator tiada: tekan **Ctrl+D**.
3. Tekan **F7**, atau butang **Compile**.
4. Lihat panel bawah (**Toolbox → tab Errors**). Baris terakhir mestilah:
   ```
   0 errors, 0 warnings
   ```
5. Ulang langkah 2–4 untuk **Experts → QuarterlyTheory → QT_EA.mq5**.

**Jika ada error:** klik pada error itu, ambil screenshot atau salin semua baris merah, dan hantar kepada Claude. Jangan ubah kod sendiri.

---

## Bahagian E — Jalankan ujian unit

Ujian ini memastikan logik EA (masa NY, True Open, SSMT, lot dan lain-lain) kira dengan betul.

1. Kembali ke MT5. Buka mana-mana chart, contohnya klik kanan **XAUUSD** di Market Watch → **Chart Window**.
2. Tekan **Ctrl+N** untuk buka **Navigator**. Kembangkan **Scripts → QuarterlyTheory**.
   - Jika tiada: klik kanan **Scripts** → **Refresh**.
3. **Seret** (drag) `QT_Tests` ke atas chart, kemudian tekan **OK** jika ada tetingkap.
4. Tekan **Ctrl+T** untuk buka **Toolbox** di bawah, dan pilih tab **Experts**.
5. Cari baris:
   ```
   QT TESTS: 88 passed, 0 failed
   ```
   (Nombor "passed" mungkin berbeza. Yang penting **0 failed**.)

**Jika ada `FAIL: ...`:** salin semua baris FAIL dan hantar kepada Claude.

---

## Bahagian F — Semak simbol dan masa broker

1. Tekan **Ctrl+M** untuk buka **Market Watch**. Klik kanan → **Symbols**.
2. Cari dan tekan **Show Symbol** untuk:
   - `XAUUSD` dan `XAGUSD` (emas dan perak)
   - `NDXUSD` (Nasdaq) dan indeks S&P 500 (cuba cari `SPX`, `US500`, `SP500`)
3. **Catat nama tepat** simbol S&P 500. Jika bukan `SPXUSD`, buka `MQL5\Profiles\Tester\QT_NDXUSD.set` dengan Notepad dan tukar baris `InpPairSymbol=SPXUSD` kepada nama sebenar.
4. **Semak masa server.** Market Watch menunjukkan jam server di bahagian atas. Bandingkan dengan waktu New York sekarang (Google: "time in New York").
   - Jika **server = NY + 7 jam**, tiada perubahan diperlukan.
   - Jika lain: beritahu Claude beza jamnya.

---

## Bahagian G — Backtest pertama (1 minggu, mod visual)

Tujuan: lihat dengan mata sendiri bahawa EA buat apa yang kita rancang.

1. Dalam MT5 tekan **Ctrl+R** untuk buka **Strategy Tester**.
2. Tab **Overview/Settings**, isi:

   | Medan | Nilai |
   |---|---|
   | Expert | `QuarterlyTheory\QT_EA.ex5` |
   | Symbol | `XAUUSD` |
   | Timeframe | `M1` |
   | Date | **Custom period**: `2026.06.08` – `2026.06.13` |
   | Forward | No |
   | Delays | Zero latency |
   | Modelling | **Every tick based on real ticks** |
   | Deposit | `1000` `USD` |
   | Leverage | ikut akaun anda (contoh 1:100) |
   | Visual mode | ✅ tandakan |

3. Tab **Inputs** → klik kanan → **Load** → pilih `QT_XAUUSD.set`.
4. Tekan **Start**. Kali pertama mungkin lambat kerana MT5 memuat turun data tick.
5. Satu tetingkap chart akan dibuka dan bergerak. Perhatikan:
   - Trade dibuka hanya dalam Q3 sesi (contoh NY AM: 09:00–10:30 waktu NY = 16:00–17:30 waktu server).
   - Garisan SL dan TP sama jarak (1:1).
   - Trade yang belum selesai ditutup sebelum akhir sesi.
6. Selepas tamat, lihat tab **Journal** dalam Strategy Tester:
   - Baris `QT XAUUSD NYAM Q3: no_ssmt`, `no_mss`, `to_filter` dan seumpamanya ialah sebab EA **tidak** masuk trade. Ini normal.
   - Baris `QT XAUUSD NYAM BUY lot=0.05 ...` bermaksud EA masuk trade.
   - Di hujung ada jadual `=== QT REPORT XAUUSD ===`.

---

## Bahagian H — Backtest penuh (2 tahun)

1. Sama seperti Bahagian G, tetapi:
   - Date: `2024.11.01` – `2026.11.01`
   - **Visual mode: TIDAK ditanda** (supaya laju)
2. Tekan **Start** dan tunggu. Ini boleh ambil masa beberapa minit hingga sejam.
3. Selepas tamat, buka tab **Backtest** dan catat:
   - **Total Trades**
   - **Profit Trades (% of total)**, iaitu win rate
   - **Profit Factor**
   - **Maximal Drawdown**
   - **Total Net Profit**
4. Ulang untuk **NDXUSD** dengan preset `QT_NDXUSD.set`.
5. Fail `QT_Report_XAUUSD.csv` (statistik per sesi) disimpan dalam folder Tester. Cara paling mudah mencarinya: Windows Explorer → cari `QT_Report` dalam folder `%APPDATA%\MetaQuotes`.

---

## Bahagian I — Hantar keputusan kepada Claude

Hantar:
1. Screenshot tab **Backtest** (XAUUSD dan NDXUSD)
2. Isi fail `QT_Report_*.csv` atau jadual `=== QT REPORT ===` dari Journal
3. Apa-apa error atau baris pelik dalam Journal

Claude akan bantu nilai sama ada strategi ini ada edge, dan apa yang patut diubah.

---

### Istilah ringkas

| Istilah | Maksud |
|---|---|
| EA | Expert Advisor — robot trading dalam MT5 |
| Compile | Tukar kod `.mq5` jadi program `.ex5` |
| Backtest | Uji strategi atas data harga lama |
| Preset (`.set`) | Fail simpan tetapan input EA |
| Win rate | % trade yang untung |
| Profit Factor | Jumlah untung ÷ jumlah rugi (> 1 = untung) |
| Drawdown | Kejatuhan baki terbesar dari puncak |
