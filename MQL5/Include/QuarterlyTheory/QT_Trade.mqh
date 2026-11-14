//+------------------------------------------------------------------+
//| QT_Trade.mqh - order execution and trade-history queries           |
//+------------------------------------------------------------------+
#ifndef QT_TRADE_MQH
#define QT_TRADE_MQH

#include <Trade/Trade.mqh>
#include "QT_Signal.mqh"

CTrade g_qtTrade;

bool QT_Open(string sym, const QTSignal &s, double lot, long magic, string comment)
  {
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double ts  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   double sl = s.sl, tp = s.tp;
   if(ts > 0) { sl = MathRound(sl/ts)*ts; tp = MathRound(tp/ts)*ts; }
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);
   g_qtTrade.SetExpertMagicNumber(magic);
   bool ok = false;
   if(s.dir == DIR_BUY)  ok = g_qtTrade.Buy(lot, sym, 0.0, sl, tp, comment);
   if(s.dir == DIR_SELL) ok = g_qtTrade.Sell(lot, sym, 0.0, sl, tp, comment);
   if(!ok)
      PrintFormat("QT: order failed retcode=%u %s", g_qtTrade.ResultRetcode(), g_qtTrade.ResultRetcodeDescription());
   return ok;
  }

int QT_OpenPositions(string sym, long magic)
  {
   int c = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == sym && PositionGetInteger(POSITION_MAGIC) == magic) c++;
     }
   return c;
  }

void QT_CloseAll(string sym, long magic)
  {
   g_qtTrade.SetExpertMagicNumber(magic);
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != sym || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(g_qtTrade.PositionClose(t))
         PrintFormat("QT: forced close #%I64u before frame end", t);
     }
  }

// Close our positions opened before frameStartServer (i.e. in an earlier frame).
void QT_CloseOlderThan(string sym, long magic, datetime frameStartServer)
  {
   g_qtTrade.SetExpertMagicNumber(magic);
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != sym || PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if((datetime)PositionGetInteger(POSITION_TIME) < frameStartServer)
        {
         if(g_qtTrade.PositionClose(t))
            PrintFormat("QT: forced close #%I64u at end of frame", t);
        }
     }
  }

// Realised P/L (profit+swap+commission) of our deals since fromServer.
double QT_RealisedSince(string sym, long magic, datetime fromServer)
  {
   if(!HistorySelect(fromServer, TimeCurrent() + 60)) return 0.0;
   double sum = 0.0;
   int total = HistoryDealsTotal();
   for(int i=0; i<total; i++)
     {
      ulong t = HistoryDealGetTicket(i);
      if(HistoryDealGetString(t, DEAL_SYMBOL) != sym) continue;
      if(HistoryDealGetInteger(t, DEAL_MAGIC) != magic) continue;
      sum += HistoryDealGetDouble(t, DEAL_PROFIT) + HistoryDealGetDouble(t, DEAL_SWAP)
           + HistoryDealGetDouble(t, DEAL_COMMISSION);
     }
   return sum;
  }

// Number of entries (DEAL_ENTRY_IN) since fromServer.
int QT_EntriesSince(string sym, long magic, datetime fromServer)
  {
   if(!HistorySelect(fromServer, TimeCurrent() + 60)) return 0;
   int c = 0;
   int total = HistoryDealsTotal();
   for(int i=0; i<total; i++)
     {
      ulong t = HistoryDealGetTicket(i);
      if(HistoryDealGetString(t, DEAL_SYMBOL) != sym) continue;
      if(HistoryDealGetInteger(t, DEAL_MAGIC) != magic) continue;
      if(HistoryDealGetInteger(t, DEAL_ENTRY) == DEAL_ENTRY_IN) c++;
     }
   return c;
  }

#endif
