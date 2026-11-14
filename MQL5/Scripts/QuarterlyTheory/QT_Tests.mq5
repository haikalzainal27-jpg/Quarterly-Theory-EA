//+------------------------------------------------------------------+
//| QT_Tests.mq5 - unit tests for Quarterly Theory EA logic            |
//| Run as a script; check the Experts log for "QT TESTS:" summary.    |
//+------------------------------------------------------------------+
#include <QuarterlyTheory/QT_TestLib.mqh>
#include <QuarterlyTheory/QT_Types.mqh>
#include <QuarterlyTheory/QT_Time.mqh>
#include <QuarterlyTheory/QT_TrueOpen.mqh>
#include <QuarterlyTheory/QT_Ranges.mqh>
#include <QuarterlyTheory/QT_SSMT.mqh>
#include <QuarterlyTheory/QT_Structure.mqh>
#include <QuarterlyTheory/QT_Risk.mqh>
#include <QuarterlyTheory/QT_Signal.mqh>
#include <QuarterlyTheory/QT_Report.mqh>

//--- helpers -------------------------------------------------------
void SetBar(MqlRates &r[], int i, datetime t, double o, double h, double l, double c)
  {
   r[i].time = t; r[i].open = o; r[i].high = h; r[i].low = l; r[i].close = c;
   r[i].tick_volume = 1; r[i].spread = 0; r[i].real_volume = 0;
  }

QTRange MkRange(double h, double l)
  {
   QTRange r; ZeroMemory(r);
   r.valid = true; r.high = h; r.low = l;
   return r;
  }

//--- Task 1 --------------------------------------------------------
void Test_Harness() { QT_AssertTrue(true, "harness"); }

//--- Task 2: time --------------------------------------------------
void Test_Time()
  {
   QT_AssertTrue(!QT_IsUSDST(D'2026.03.08 06:59'), "dst before start");
   QT_AssertTrue( QT_IsUSDST(D'2026.03.08 07:00'), "dst at start");
   QT_AssertTrue( QT_IsUSDST(D'2026.11.01 05:59'), "dst before end");
   QT_AssertTrue(!QT_IsUSDST(D'2026.11.01 06:00'), "dst at end");

   QT_AssertEqTime(D'2026.06.10 09:30', QT_ServerToNY(D'2026.06.10 16:30', TIME_NY_PLUS_7, 0), "ny+7");
   QT_AssertEqTime(D'2026.06.10 09:30', QT_ServerToNY(D'2026.06.10 13:30', TIME_MANUAL_GMT, 0), "manual EDT");
   QT_AssertEqTime(D'2026.01.10 09:30', QT_ServerToNY(D'2026.01.10 14:30', TIME_MANUAL_GMT, 0), "manual EST");

   datetime ts[4] = {D'2026.06.10 16:30', D'2026.01.10 14:30', D'2026.03.09 10:00', D'2026.11.02 10:00'};
   for(int i=0; i<4; i++)
     {
      QT_AssertEqTime(ts[i], QT_NYToServer(QT_ServerToNY(ts[i], TIME_NY_PLUS_7, 0), TIME_NY_PLUS_7, 0), "roundtrip ny+7");
      QT_AssertEqTime(ts[i], QT_NYToServer(QT_ServerToNY(ts[i], TIME_MANUAL_GMT, 2), TIME_MANUAL_GMT, 2), "roundtrip manual");
     }

   QTCyclePos p = QT_GetCyclePos(D'2026.06.10 09:30', MODEL_SESSION_90M);
   QT_AssertEqInt(QT_NYAM, p.session, "pos session");
   QT_AssertEqInt(2, p.cycle90Idx, "pos cycle90");
   QT_AssertEqInt(1, p.microIdx, "pos micro");
   QT_AssertEqInt(2, p.frameQuarter, "pos frameQuarter");
   QT_AssertEqTime(D'2026.06.10 06:00', p.frameStartNY, "pos frameStart");

   p = QT_GetCyclePos(D'2026.06.10 19:00', MODEL_SESSION_90M);
   QT_AssertEqInt(QT_ASIA, p.session, "asia session");
   QT_AssertEqTime(D'2026.06.10 18:00', p.tradingDayStartNY, "asia day start");
   p = QT_GetCyclePos(D'2026.06.10 17:59', MODEL_SESSION_90M);
   QT_AssertEqTime(D'2026.06.09 18:00', p.tradingDayStartNY, "pm day start");
   QT_AssertEqInt(QT_NYPM, p.session, "pm session");

   // forced close: NY AM ends 12:00 -> 11:58; NY PM capped at 17:00 break -> 16:58
   QTCyclePos fc = QT_GetCyclePos(D'2026.06.10 10:00', MODEL_SESSION_90M);
   QT_AssertEqTime(D'2026.06.10 11:58', QT_ForceCloseTimeNY(fc, 2), "force close NY AM");
   fc = QT_GetCyclePos(D'2026.06.10 15:00', MODEL_SESSION_90M);
   QT_AssertEqTime(D'2026.06.10 16:58', QT_ForceCloseTimeNY(fc, 2), "force close NY PM before break");

   p = QT_GetCyclePos(D'2026.06.10 09:30', MODEL_CYCLE_MICRO);
   QT_AssertEqTime(D'2026.06.10 09:00', p.frameStartNY, "micro frameStart");
   QT_AssertEqInt(1, p.frameQuarter, "micro frameQuarter");
  }

//--- Task 3: True Open ---------------------------------------------
void Test_TrueOpen()
  {
   datetime d, s, c;
   QTCyclePos p = QT_GetCyclePos(D'2026.06.10 09:30', MODEL_SESSION_90M);
   QT_TrueOpenTimesNY(p, d, s, c);
   QT_AssertEqTime(D'2026.06.10 00:00',    d, "daily TO");
   QT_AssertEqTime(D'2026.06.10 07:30',    s, "session TO");
   QT_AssertEqTime(D'2026.06.10 09:22:30', c, "cycle TO");

   p = QT_GetCyclePos(D'2026.06.10 19:00', MODEL_SESSION_90M);
   QT_TrueOpenTimesNY(p, d, s, c);
   QT_AssertEqTime(D'2026.06.11 00:00', d, "asia daily TO in future");
   QT_AssertTrue(d > p.nyTime, "asia daily TO not formed");
   QT_AssertEqTime(D'2026.06.10 19:30', s, "asia session TO");

   double pr[3]; bool fm[3] = {true, true, true};
   pr[0]=101; pr[1]=102; pr[2]=99;
   QT_AssertTrue(QT_TrueOpenPass(DIR_BUY, 100, pr, fm), "buy 2 votes pass");
   pr[0]=99; pr[1]=98; pr[2]=101;
   QT_AssertTrue(QT_TrueOpenPass(DIR_SELL, 100, pr, fm), "sell 2 votes pass");
   bool fm2[3] = {true, false, false};
   pr[0]=101; pr[1]=0; pr[2]=0;
   QT_AssertEqInt(1, QT_TrueOpenVotes(DIR_BUY, 100, pr, fm2), "only formed counted");
   QT_AssertTrue(!QT_TrueOpenPass(DIR_BUY, 100, pr, fm2), "1 formed TO fails");
  }

//--- Task 4: ranges ------------------------------------------------
void Test_Ranges()
  {
   MqlRates r[]; ArrayResize(r, 6);
   datetime t0 = D'2026.06.10 10:00';
   double hs[6] = {10,12,11,13,9,8};
   double ls[6] = { 5, 6, 4, 7,3,2};
   for(int i=0; i<6; i++) SetBar(r, i, t0+60*i, ls[i], hs[i], ls[i], ls[i]);

   QTRange g = QT_RangeBetween(r, t0+60, t0+240);
   QT_AssertTrue(g.valid, "range valid");
   QT_AssertEqDbl(13, g.high, 1e-9, "range high");
   QT_AssertEqDbl(4,  g.low,  1e-9, "range low");
   QT_AssertEqTime(t0+180, g.highTime, "range highTime");
   QT_AssertEqTime(t0+120, g.lowTime,  "range lowTime");

   QTRange e = QT_RangeBetween(r, t0+3600, t0+7200);
   QT_AssertTrue(!e.valid, "empty range invalid");

   QTRange x = QT_RangeBetween(r, t0, t0+60);
   QT_AssertEqDbl(10, x.high, 1e-9, "to is exclusive");
  }

//--- Task 5: SSMT --------------------------------------------------
void Test_SSMT()
  {
   QTRange mQ1 = MkRange(110, 100), pQ1 = MkRange(55, 50);
   QTRange a = MkRange(108, 99),  b = MkRange(54, 50.5);
   QT_AssertEqInt(DIR_BUY,  QT_DetectSSMT(mQ1, a, pQ1, b), "bull ssmt");
   a = MkRange(111, 102); b = MkRange(55, 51);
   QT_AssertEqInt(DIR_SELL, QT_DetectSSMT(mQ1, a, pQ1, b), "bear ssmt");
   a = MkRange(108, 99);  b = MkRange(54, 49);
   QT_AssertEqInt(DIR_NONE, QT_DetectSSMT(mQ1, a, pQ1, b), "both swept low");
   a = MkRange(111, 99);  b = MkRange(54, 51);
   QT_AssertEqInt(DIR_NONE, QT_DetectSSMT(mQ1, a, pQ1, b), "main swept both");
   QTRange bad = MkRange(0,0); bad.valid = false;
   a = MkRange(108, 99);
   QT_AssertEqInt(DIR_NONE, QT_DetectSSMT(mQ1, a, pQ1, bad), "invalid range");
  }

//--- Task 6: structure ---------------------------------------------
void BuildMSSBars(MqlRates &r[], int n, bool buy, datetime t0)
  {
   ArrayResize(r, n);
   for(int i=0; i<n; i++)
     {
      if(buy) SetBar(r, i, t0+60*i, 9.5, 10, 9, 9.5);
      else    SetBar(r, i, t0+60*i, 9.5, 10, 9, 9.5);
     }
   if(buy) { r[5].high = 12; r[9].high = 13; r[9].close = 12.5; }
   else    { r[5].low  = 7;  r[9].low  = 6;  r[9].close = 6.5;  }
  }

void Test_Structure()
  {
   datetime t0 = D'2026.06.10 10:00';
   MqlRates r[]; double lvl;

   BuildMSSBars(r, 10, true, t0);
   QT_AssertTrue(QT_IsFractalHigh(r, 5), "fractal high");
   QT_AssertTrue(QT_DetectMSS(r, DIR_BUY, t0, lvl), "buy mss");
   QT_AssertEqDbl(12, lvl, 1e-9, "buy mss level");

   BuildMSSBars(r, 11, true, t0);
   r[10].close = 12.6; r[10].high = 12.8;
   QT_AssertTrue(!QT_DetectMSS(r, DIR_BUY, t0, lvl), "not first break");

   BuildMSSBars(r, 10, true, t0);
   QT_AssertTrue(!QT_DetectMSS(r, DIR_BUY, t0+360, lvl), "fractal before afterTime ignored");

   BuildMSSBars(r, 10, true, t0);
   QT_AssertTrue(!QT_DetectMSS(r, DIR_BUY, t0+300, lvl), "fractal on sweep bar ignored");

   BuildMSSBars(r, 10, false, t0);
   QT_AssertTrue(QT_IsFractalLow(r, 5), "fractal low");
   QT_AssertTrue(QT_DetectMSS(r, DIR_SELL, t0, lvl), "sell mss");
   QT_AssertEqDbl(7, lvl, 1e-9, "sell mss level");
  }

//--- Task 7: risk --------------------------------------------------
void Test_Risk()
  {
   QT_AssertEqDbl(0.05, QT_CalcLot(10, 2.00, 1.0, 0.01, 0.01, 0.01), 1e-9, "xau lot");
   QT_AssertEqDbl(0.05, QT_CalcLot(10, 1.67, 1.0, 0.01, 0.01, 0.01), 1e-9, "round down");
   double ndx = QT_CalcLot(10, 150.0, 0.01, 0.01, 0.1, 0.1);
   QT_AssertEqDbl(0.0, ndx, 1e-12, "ndx lot below min -> 0");
   QT_AssertEqInt(SKIP_LOT_MIN, QT_CheckScalpFilters(15000, 100, ndx, 3, 200, 5), "lot min skip");

   QT_AssertEqInt(SKIP_SL_TOO_SMALL, QT_CheckScalpFilters(20, 8, 0.1, 3, 50, 5), "sl too small");
   QT_AssertEqInt(SKIP_SPREAD,       QT_CheckScalpFilters(1000, 60, 0.1, 3, 50, 5), "spread");
   QT_AssertEqInt(SKIP_LOT_MAX,      QT_CheckScalpFilters(1000, 8, 6.0, 3, 50, 5), "lot max");
   QT_AssertEqInt(SKIP_NONE,         QT_CheckScalpFilters(1000, 8, 0.1, 3, 50, 5), "filters ok");

   QT_AssertEqInt(SKIP_DAILY_LOSS, QT_CheckDailyLimits(-30, 0, 0, 30, 3, 1), "daily loss");
   QT_AssertEqInt(SKIP_MAX_DAY,    QT_CheckDailyLimits(0, 3, 0, 30, 3, 1),   "max day");
   QT_AssertEqInt(SKIP_MAX_CYCLE,  QT_CheckDailyLimits(0, 1, 1, 30, 3, 1),   "max cycle");
   QT_AssertEqInt(SKIP_NONE,       QT_CheckDailyLimits(-29.99, 2, 0, 30, 3, 1), "limits ok");
  }

//--- Task 8: signal ------------------------------------------------
void BuildSignalCase(QTSignalInput &in, MqlRates &m1[], int bars)
  {
   datetime T = D'2026.06.10 16:00';          // Q3 start (server time)
   ArrayResize(m1, bars);
   for(int i=0; i<bars; i++) SetBar(m1, i, T-600+60*i, 99, 100, 98, 99);
   m1[0].low = 95;                              // Q2 sweep
   m1[5].high = 101;                            // fractal high after sweep
   if(bars >= 12) { m1[11].close = 101.5; m1[11].high = 102; m1[11].low = 99; }

   ZeroMemory(in);
   in.pos = QT_GetCyclePos(D'2026.06.10 09:30', MODEL_SESSION_90M); // Q3
   in.mainQ1 = MkRange(105, 96);
   in.mainQ2 = MkRange(100, 95); in.mainQ2.lowTime = T-600; in.mainQ2.highTime = T-540;
   in.pairQ1 = MkRange(50, 40);
   in.pairQ2 = MkRange(48, 41);
   in.q3StartServer = T;
   in.toDaily = 103; in.toSession = 104; in.toCycle = 90;
   in.toDailyFormed = true; in.toSessionFormed = true; in.toCycleFormed = true;
   in.bid = 101.5; in.ask = 101.6;
   in.useSSMT = true; in.useTO = true; in.useMSS = true;
  }

void Test_Signal()
  {
   QTSignalInput in; MqlRates m1[]; QTSignal s;

   BuildSignalCase(in, m1, 12);
   QT_BuildSignal(in, m1, 0.1, s);
   QT_AssertEqInt(DIR_BUY, s.dir, "signal buy");
   QT_AssertEqDbl(94.9, s.sl, 1e-9, "signal sl");
   QT_AssertEqDbl(s.entry - s.sl, s.tp - s.entry, 1e-9, "rr 1:1");

   BuildSignalCase(in, m1, 12);
   in.pos = QT_GetCyclePos(D'2026.06.10 08:00', MODEL_SESSION_90M); // Q2
   QT_BuildSignal(in, m1, 0.1, s);
   QT_AssertEqInt(DIR_NONE, s.dir, "not in q3");

   BuildSignalCase(in, m1, 12);
   in.bid = 94.0; in.ask = 94.1;
   QT_BuildSignal(in, m1, 0.1, s);
   QT_AssertTrue(s.dir == DIR_NONE && s.reason == "invalidated", "invalidated");

   BuildSignalCase(in, m1, 12);
   in.toDaily = 100; in.toSession = 99; in.toCycle = 103;
   QT_BuildSignal(in, m1, 0.1, s);
   QT_AssertEqInt(SKIP_TO_FILTER, s.skip, "to filter skip");

   BuildSignalCase(in, m1, 11);
   QT_BuildSignal(in, m1, 0.1, s);
   QT_AssertTrue(s.dir == DIR_NONE && s.reason == "no_mss", "no mss");
   in.useMSS = false;
   QT_BuildSignal(in, m1, 0.1, s);
   QT_AssertEqInt(DIR_BUY, s.dir, "mss disabled -> entry");
  }

//--- Task 10: report -----------------------------------------------
void Test_Report()
  {
   QT_AssertEqInt(QT_NYAM, QT_SessionFromComment("QT|NYAM|2"), "comment -> session");
   QT_AssertEqInt(-1, QT_SessionFromComment("manual"), "foreign comment");

   int ss[6] = {2,2,2,1,1,0};
   double pf[6] = {10,10,10,-10,-10,0};
   QTStats st[];
   QT_AggregateStats(ss, pf, st);
   QT_AssertEqInt(6, st[4].trades, "total trades");
   QT_AssertEqInt(0, st[QT_ASIA].wins + st[QT_ASIA].losses, "breakeven is neither");
   QT_AssertEqDbl(10, st[4].net, 1e-9, "total net");
   QT_AssertEqDbl(50.0, QT_WinRate(st[4]), 1e-9, "total winrate (3 of 6)");
   QT_AssertEqInt(3, st[QT_NYAM].wins, "nyam wins");
   QT_AssertEqInt(2, st[QT_LONDON].losses, "london losses");
  }

void OnStart()
  {
   Test_Harness();
   Test_Time();
   Test_TrueOpen();
   Test_Ranges();
   Test_SSMT();
   Test_Structure();
   Test_Risk();
   Test_Signal();
   Test_Report();
   QT_TestSummary();
  }
