//+------------------------------------------------------------------+
//| QT_EA.mq5 - Quarterly Theory scalping EA                           |
//| AMDX (90-min quarters) + SSMT + 3 True Opens + M1 MSS, RR 1:1      |
//+------------------------------------------------------------------+
#property copyright "Quarterly Theory EA"
#property version   "1.00"

#include <QuarterlyTheory/QT_Types.mqh>
#include <QuarterlyTheory/QT_Time.mqh>
#include <QuarterlyTheory/QT_TrueOpen.mqh>
#include <QuarterlyTheory/QT_Ranges.mqh>
#include <QuarterlyTheory/QT_SSMT.mqh>
#include <QuarterlyTheory/QT_Structure.mqh>
#include <QuarterlyTheory/QT_Risk.mqh>
#include <QuarterlyTheory/QT_Signal.mqh>
#include <QuarterlyTheory/QT_Data.mqh>
#include <QuarterlyTheory/QT_Trade.mqh>
#include <QuarterlyTheory/QT_Report.mqh>

input group "Masa"
input QTTimeMode   InpTimeMode          = TIME_NY_PLUS_7;   // Mod masa server
input int          InpServerGmtOffset   = 2;                // Offset GMT server (mod manual sahaja)
input QTModelLevel InpModelLevel        = MODEL_SESSION_90M;// Peringkat model

input group "Simbol"
input string       InpPairSymbol        = "XAGUSD.s";         // Simbol pasangan SSMT

input group "Risiko"
input double       InpRiskUSD           = 10.0;             // Risiko setiap trade (USD)
input double       InpDailyLossUSD      = 30.0;             // Had rugi harian (USD)
input int          InpMaxTradesPerDay   = 3;
input int          InpMaxTradesPerCycle = 1;
input double       InpMaxSpreadPoints   = 50;
input double       InpMinSLSpreadMult   = 3.0;
input double       InpMaxLot            = 5.0;
input double       InpSLBufferPoints    = 0;                // 0 = guna spread semasa
input bool         InpRoundLotUp        = false;            // Bundar lot ke atas (risiko maks 1.5x)

input group "Komponen model"
input bool         InpUseSSMT           = true;
input bool         InpUseTO             = true;
input bool         InpUseMSS            = true;

input group "Sesi"
input bool         InpTradeAsia         = true;
input bool         InpTradeLondon       = true;
input bool         InpTradeNYAM         = true;
input bool         InpTradeNYPM         = true;

input group "Lain-lain"
input long         InpMagic             = 20261114;
input int          InpCloseBufferMin    = 2;                // Tutup paksa N minit sebelum akhir Q4 / 17:00 NY
input int          InpDeviationPoints   = 20;               // Slippage maksimum

datetime g_lastBar     = 0;
datetime g_startServer = 0;
datetime g_logFrame    = 0;
datetime g_detailFrame = 0;
string   g_lastReason  = "";

datetime NY2S(datetime ny) { return QT_NYToServer(ny, InpTimeMode, InpServerGmtOffset); }
datetime S2NY(datetime s)  { return QT_ServerToNY(s, InpTimeMode, InpServerGmtOffset); }

bool SessionEnabled(QTSession s)
  {
   switch(s)
     {
      case QT_ASIA:   return InpTradeAsia;
      case QT_LONDON: return InpTradeLondon;
      case QT_NYAM:   return InpTradeNYAM;
      case QT_NYPM:   return InpTradeNYPM;
     }
   return false;
  }

void LogOnce(const QTCyclePos &p, string msg)
  {
   if(p.frameStartNY != g_logFrame) { g_logFrame = p.frameStartNY; g_lastReason = ""; }
   if(msg == g_lastReason) return;
   g_lastReason = msg;
   PrintFormat("QT %s %s Q%d: %s", _Symbol, QT_SessionName(p.session), p.frameQuarter+1, msg);
  }

int OnInit()
  {
   if(!SymbolSelect(InpPairSymbol, true))
     {
      PrintFormat("QT: simbol pasangan '%s' tiada di broker ini", InpPairSymbol);
      return INIT_PARAMETERS_INCORRECT;
     }
   if(AccountInfoString(ACCOUNT_CURRENCY) != "USD")
      Print("QT: amaran - mata wang akaun bukan USD, risiko dikira dalam mata wang akaun");
   g_startServer = TimeCurrent();
   g_qtTrade.SetExpertMagicNumber(InpMagic);
   // Warm up pair history so the tester loads it (multi-symbol data).
   MqlRates warm[];
   int got = CopyRates(InpPairSymbol, PERIOD_M1, 0, 500, warm);
   PrintFormat("QT init: symbol=%s pair=%s pairBars=%d digits=%d point=%g timeMode=%d",
               _Symbol, InpPairSymbol, got, _Digits, _Point, (int)InpTimeMode);
   g_qtTrade.SetTypeFillingBySymbol(_Symbol);
   g_qtTrade.SetDeviationInPoints(InpDeviationPoints);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QT_ReportBuild(_Symbol, InpMagic, g_startServer, "QT_Report_" + _Symbol + ".csv");
  }

void OnTick()
  {
   datetime barTime = iTime(_Symbol, PERIOD_M1, 0);
   if(barTime == 0 || barTime == g_lastBar) return;
   g_lastBar = barTime;

   datetime   nyNow = S2NY(barTime);
   QTCyclePos p     = QT_GetCyclePos(nyNow, InpModelLevel);
   datetime   frameStartS = NY2S(p.frameStartNY);

   // Forced close: before end of Q4 (or 17:00 NY daily break), and anything
   // left over from an earlier frame.
   QT_CloseOlderThan(_Symbol, InpMagic, frameStartS);
   if(nyNow >= QT_ForceCloseTimeNY(p, InpCloseBufferMin))
     {
      QT_CloseAll(_Symbol, InpMagic);
      return;
     }

   if(p.frameQuarter != 2) return;                 // entries only in Q3
   if(!SessionEnabled(p.session)) return;
   if(QT_OpenPositions(_Symbol, InpMagic) > 0) return;

   // Daily / per-cycle limits
   datetime dayStartS   = NY2S(p.tradingDayStartNY);
   datetime cycleStartS = NY2S(p.cycle90StartNY);
   QTSkip lim = QT_CheckDailyLimits(QT_RealisedSince(_Symbol, InpMagic, dayStartS),
                                    QT_EntriesSince(_Symbol, InpMagic, dayStartS),
                                    QT_EntriesSince(_Symbol, InpMagic, cycleStartS),
                                    InpDailyLossUSD, InpMaxTradesPerDay, InpMaxTradesPerCycle);
   if(lim != SKIP_NONE) { LogOnce(p, "skip " + QT_SkipName(lim)); return; }

   // Data: closed bars of the current frame
   int      q    = p.frameQuarterSec;
   datetime q2S  = NY2S(p.frameStartNY + q);
   datetime q3S  = NY2S(p.frameStartNY + 2*q);
   MqlRates mainM1[], pairM1[];
   if(!QT_LoadM1(_Symbol, frameStartS, barTime - 1, mainM1))
     { LogOnce(p, StringFormat("data_fail %s err=%d", _Symbol, GetLastError())); return; }
   if(InpUseSSMT && !QT_LoadM1(InpPairSymbol, frameStartS, barTime - 1, pairM1))
     { LogOnce(p, StringFormat("data_fail %s err=%d", InpPairSymbol, GetLastError())); return; }

   QTSignalInput in;
   ZeroMemory(in);
   in.pos    = p;
   in.mainQ1 = QT_RangeBetween(mainM1, frameStartS, q2S);
   in.mainQ2 = QT_RangeBetween(mainM1, q2S, q3S);
   in.pairQ1 = QT_RangeBetween(pairM1, frameStartS, q2S);
   in.pairQ2 = QT_RangeBetween(pairM1, q2S, q3S);
   in.q3StartServer = q3S;

   datetime dTO, sTO, cTO;
   QT_TrueOpenTimesNY(p, dTO, sTO, cTO);
   in.toDaily   = (nyNow >= dTO) ? QT_PriceAt(_Symbol, NY2S(dTO)) : 0.0;
   in.toSession = (nyNow >= sTO) ? QT_PriceAt(_Symbol, NY2S(sTO)) : 0.0;
   in.toCycle   = (nyNow >= cTO) ? QT_PriceAt(_Symbol, NY2S(cTO)) : 0.0;
   in.toDailyFormed   = in.toDaily   > 0.0;
   in.toSessionFormed = in.toSession > 0.0;
   in.toCycleFormed   = in.toCycle   > 0.0;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;

   // One detail line per frame at the start of Q3 (diagnostics)
   if(p.frameStartNY != g_detailFrame)
     {
      g_detailFrame = p.frameStartNY;
      PrintFormat("QT %s %s detail: NY=%s mainBars=%d pairBars=%d | main Q1 %.2f-%.2f Q2 %.2f-%.2f | pair Q1 %.3f-%.3f Q2 %.3f-%.3f | TO d=%.2f s=%.2f c=%.2f | spreadPts=%.0f",
                  _Symbol, QT_SessionName(p.session), TimeToString(nyNow, TIME_DATE|TIME_MINUTES),
                  ArraySize(mainM1), ArraySize(pairM1),
                  in.mainQ1.low, in.mainQ1.high, in.mainQ2.low, in.mainQ2.high,
                  in.pairQ1.low, in.pairQ1.high, in.pairQ2.low, in.pairQ2.high,
                  in.toDaily, in.toSession, in.toCycle, (tick.ask - tick.bid) / _Point);
     }
   in.bid = tick.bid; in.ask = tick.ask;
   in.useSSMT = InpUseSSMT; in.useTO = InpUseTO; in.useMSS = InpUseMSS;

   double spreadPrice = tick.ask - tick.bid;
   double buffer = (InpSLBufferPoints > 0) ? InpSLBufferPoints * _Point : spreadPrice;

   QTSignal s;
   QT_BuildSignal(in, mainM1, buffer, s);
   if(s.dir == DIR_NONE) { LogOnce(p, s.reason); return; }

   // Lot & scalping filters
   double dist  = MathAbs(s.entry - s.sl);
   double lot   = QT_CalcLot(InpRiskUSD, dist,
                             SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE),
                             SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE),
                             SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN),
                             SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP),
                             InpRoundLotUp, 1.5);
   QTSkip f = QT_CheckScalpFilters(dist / _Point, spreadPrice / _Point, lot,
                                   InpMinSLSpreadMult, InpMaxSpreadPoints, InpMaxLot);
   if(f != SKIP_NONE) { LogOnce(p, "skip " + QT_SkipName(f)); return; }

   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stopsLevel > 0 && dist / _Point < stopsLevel) { LogOnce(p, "skip STOPS_LEVEL"); return; }

   string comment = StringFormat("QT|%s|%d", QT_SessionName(p.session), p.cycle90Idx);
   double riskUSD = dist / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE)
                  * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) * lot;
   if(QT_Open(_Symbol, s, lot, InpMagic, comment))
      PrintFormat("QT %s %s %s lot=%.2f entry=%.5f sl=%.5f tp=%.5f risk=$%.2f",
                  _Symbol, QT_SessionName(p.session), (s.dir == DIR_BUY ? "BUY" : "SELL"),
                  lot, s.entry, s.sl, s.tp, riskUSD);
  }
