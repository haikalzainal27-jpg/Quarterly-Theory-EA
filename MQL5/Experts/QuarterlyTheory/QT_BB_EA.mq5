//+------------------------------------------------------------------+
//| QT_BB_EA.mq5 - Quarterly Theory + Bollinger Bands scalper          |
//| Bollinger re-entry (mean reversion) filtered by QT True Opens.     |
//| Fixed lot, fixed dollar risk and reward (default $5 / $5).         |
//+------------------------------------------------------------------+
#property copyright "Quarterly Theory EA"
#property version   "1.00"

#include <QuarterlyTheory/QT_Types.mqh>
#include <QuarterlyTheory/QT_Time.mqh>
#include <QuarterlyTheory/QT_TrueOpen.mqh>
#include <QuarterlyTheory/QT_Risk.mqh>
#include <QuarterlyTheory/QT_Signal.mqh>
#include <QuarterlyTheory/QT_Data.mqh>
#include <QuarterlyTheory/QT_Trade.mqh>
#include <QuarterlyTheory/QT_Report.mqh>
#include <QuarterlyTheory/QT_BB.mqh>

input group "Masa"
input QTTimeMode      InpTimeMode          = TIME_NY_PLUS_7;  // Mod masa server
input int             InpServerGmtOffset   = 2;               // Offset GMT server (mod manual sahaja)

input group "Bollinger Bands"
input ENUM_TIMEFRAMES InpBBTimeframe       = PERIOD_M5;       // Timeframe isyarat
input int             InpBBPeriod          = 20;
input double          InpBBDeviation       = 2.0;

input group "Quarterly Theory"
input bool            InpUseTO             = true;            // Penapis True Open (buy bawah TO, sell atas TO)
input int             InpMinTOVotes        = 2;               // Bilangan TO yang mesti setuju

input group "Risiko"
input double          InpFixedLot          = 0.01;            // Lot tetap
input double          InpRiskUSD           = 5.0;             // Rugi jika kena SL (USD)
input double          InpRewardMult        = 1.0;             // TP = N x risiko (1 = 1:1)
input double          InpDailyLossUSD      = 15.0;            // Had rugi harian (USD)
input int             InpMaxTradesPerDay   = 5;
input int             InpMaxTradesPerCycle = 1;               // Maks trade setiap kitaran 90 minit
input double          InpMaxSpreadPoints   = 50;

input group "Sesi"
input bool            InpTradeAsia         = true;
input bool            InpTradeLondon       = true;
input bool            InpTradeNYAM         = true;
input bool            InpTradeNYPM         = true;

input group "Lain-lain"
input long            InpMagic             = 20261116;
input int             InpCloseBufferMin    = 2;               // Tutup N minit sebelum 17:00 NY
input int             InpDeviationPoints   = 20;

datetime g_lastBar     = 0;
datetime g_startServer = 0;

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

int OnInit()
  {
   if(InpBBPeriod < 2 || InpFixedLot <= 0 || InpRiskUSD <= 0)
      return INIT_PARAMETERS_INCORRECT;
   g_startServer = TimeCurrent();
   g_qtTrade.SetExpertMagicNumber(InpMagic);
   g_qtTrade.SetTypeFillingBySymbol(_Symbol);
   g_qtTrade.SetDeviationInPoints(InpDeviationPoints);
   double dist = QT_FixedRiskDistance(InpRiskUSD, InpFixedLot,
                                      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE),
                                      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE));
   PrintFormat("QTBB init: symbol=%s lot=%.2f risk=$%.2f -> SL distance=%.2f, TP distance=%.2f",
               _Symbol, InpFixedLot, InpRiskUSD, dist, dist*InpRewardMult);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QT_ReportBuild(_Symbol, InpMagic, g_startServer, "QTBB_Report_" + _Symbol + ".csv");
  }

void OnTick()
  {
   datetime barTime = iTime(_Symbol, InpBBTimeframe, 0);
   if(barTime == 0 || barTime == g_lastBar) return;
   g_lastBar = barTime;

   datetime   nyNow = S2NY(barTime);
   QTCyclePos p     = QT_GetCyclePos(nyNow, MODEL_SESSION_90M);

   // Never hold through the 17:00 NY daily break / weekend.
   if(nyNow >= QT_ForceCloseTimeNY(p, InpCloseBufferMin + PeriodSeconds(InpBBTimeframe)/60, false))
     {
      QT_CloseAll(_Symbol, InpMagic);
      return;
     }

   if(!SessionEnabled(p.session)) return;
   if(QT_OpenPositions(_Symbol, InpMagic) > 0) return;

   datetime dayStartS   = NY2S(p.tradingDayStartNY);
   datetime cycleStartS = NY2S(p.cycle90StartNY);
   if(QT_CheckDailyLimits(QT_RealisedSince(_Symbol, InpMagic, dayStartS),
                          QT_EntriesSince(_Symbol, InpMagic, dayStartS),
                          QT_EntriesSince(_Symbol, InpMagic, cycleStartS),
                          InpDailyLossUSD, InpMaxTradesPerDay, InpMaxTradesPerCycle) != SKIP_NONE)
      return;

   // Bollinger re-entry on closed bars
   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   int need = InpBBPeriod + 2;
   if(CopyRates(_Symbol, InpBBTimeframe, 1, need, rates) < need) return;
   double closes[];
   ArrayResize(closes, need);
   for(int i=0; i<need; i++) closes[i] = rates[i].close;
   QTDir dir = QT_BBReentrySignal(closes, InpBBPeriod, InpBBDeviation);
   if(dir == DIR_NONE) return;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   double spreadPts = (tick.ask - tick.bid) / _Point;
   if(spreadPts > InpMaxSpreadPoints) return;
   double entry = (dir == DIR_BUY) ? tick.ask : tick.bid;

   // Quarterly Theory True Open filter (premium / discount)
   if(InpUseTO)
     {
      datetime dTO, sTO, cTO;
      QT_TrueOpenTimesNY(p, dTO, sTO, cTO);
      double pr[3]; bool fm[3];
      pr[0] = (nyNow >= dTO) ? QT_PriceAt(_Symbol, NY2S(dTO)) : 0.0;
      pr[1] = (nyNow >= sTO) ? QT_PriceAt(_Symbol, NY2S(sTO)) : 0.0;
      pr[2] = (nyNow >= cTO) ? QT_PriceAt(_Symbol, NY2S(cTO)) : 0.0;
      for(int k=0; k<3; k++) fm[k] = (pr[k] > 0.0);
      if(!QT_TrueOpenPass(dir, entry, pr, fm, InpMinTOVotes)) return;
     }

   double dist = QT_FixedRiskDistance(InpRiskUSD, InpFixedLot,
                                      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE),
                                      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE));
   if(dist <= 0) return;
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stopsLevel > 0 && dist / _Point < stopsLevel) return;

   QTSignal s;
   QT_SignalReset(s);
   s.dir   = dir;
   s.entry = entry;
   s.sl    = (dir == DIR_BUY) ? entry - dist : entry + dist;
   s.tp    = (dir == DIR_BUY) ? entry + dist*InpRewardMult : entry - dist*InpRewardMult;

   string comment = StringFormat("QT|%s|%d", QT_SessionName(p.session), p.cycle90Idx);
   if(QT_Open(_Symbol, s, InpFixedLot, InpMagic, comment))
      PrintFormat("QTBB %s %s %s lot=%.2f entry=%.2f sl=%.2f tp=%.2f",
                  _Symbol, QT_SessionName(p.session), (dir == DIR_BUY ? "BUY" : "SELL"),
                  InpFixedLot, s.entry, s.sl, s.tp);
  }
