//+------------------------------------------------------------------+
//| QT_Report.mqh - per-session statistics and CSV report             |
//+------------------------------------------------------------------+
#ifndef QT_REPORT_MQH
#define QT_REPORT_MQH

#include "QT_Types.mqh"

struct QTStats
  {
   int    trades;
   int    wins;
   int    losses;
   double net;
  };

// Comment format written by the EA: "QT|<SESSION>|<cycle90Idx>". Returns -1 if unknown.
int QT_SessionFromComment(string comment)
  {
   string parts[];
   if(StringSplit(comment, '|', parts) < 2) return -1;
   if(parts[0] != "QT") return -1;
   for(int s=0; s<4; s++)
      if(parts[1] == QT_SessionName((QTSession)s)) return s;
   return -1;
  }

// Aggregate closed-trade results. sessions[i] in 0..3, profits[i] net USD per trade.
// stats has 5 entries: 0..3 = sessions, 4 = TOTAL.
void QT_AggregateStats(const int &sessions[], const double &profits[], QTStats &stats[])
  {
   ArrayResize(stats, 5);
   for(int k=0; k<5; k++) { stats[k].trades=0; stats[k].wins=0; stats[k].losses=0; stats[k].net=0; }
   int n = (int)MathMin(ArraySize(sessions), ArraySize(profits));
   for(int i=0; i<n; i++)
     {
      int s = sessions[i];
      if(s < 0 || s > 3) continue;
      int idx[2]; idx[0] = s; idx[1] = 4;
      for(int j=0; j<2; j++)
        {
         stats[idx[j]].trades++;
         stats[idx[j]].net += profits[i];
         if(profits[i] > 0)      stats[idx[j]].wins++;
         else if(profits[i] < 0) stats[idx[j]].losses++; // 0 = breakeven, neither
        }
     }
  }

double QT_WinRate(const QTStats &s)
  {
   return (s.trades > 0) ? 100.0 * s.wins / s.trades : 0.0;
  }

// Reads deal history (terminal call), groups by session tag, prints & writes CSV.
void QT_ReportBuild(string sym, long magic, datetime fromServer, string fileName)
  {
   if(!HistorySelect(fromServer, TimeCurrent() + 86400)) return;

   // Map position id -> session from the entry deal comment, then sum exit profits.
   int sessions[]; double profits[];
   long posIds[]; int posSess[];
   int total = HistoryDealsTotal();
   for(int i=0; i<total; i++)
     {
      ulong t = HistoryDealGetTicket(i);
      if(HistoryDealGetString(t, DEAL_SYMBOL) != sym) continue;
      if(HistoryDealGetInteger(t, DEAL_MAGIC) != magic) continue;
      long entry = HistoryDealGetInteger(t, DEAL_ENTRY);
      long pid   = HistoryDealGetInteger(t, DEAL_POSITION_ID);
      if(entry == DEAL_ENTRY_IN)
        {
         int k = ArraySize(posIds);
         ArrayResize(posIds, k+1); ArrayResize(posSess, k+1);
         posIds[k] = pid;
         posSess[k] = QT_SessionFromComment(HistoryDealGetString(t, DEAL_COMMENT));
        }
     }
   for(int p=0; p<ArraySize(posIds); p++)
     {
      double pnl = 0; bool closed = false;
      for(int i=0; i<total; i++)
        {
         ulong t = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(t, DEAL_POSITION_ID) != posIds[p]) continue;
         long entry = HistoryDealGetInteger(t, DEAL_ENTRY);
         pnl += HistoryDealGetDouble(t, DEAL_PROFIT) + HistoryDealGetDouble(t, DEAL_SWAP)
              + HistoryDealGetDouble(t, DEAL_COMMISSION);
         if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY) closed = true;
        }
      if(!closed) continue;
      int k = ArraySize(sessions);
      ArrayResize(sessions, k+1); ArrayResize(profits, k+1);
      sessions[k] = posSess[p]; profits[k] = pnl;
     }

   QTStats st[];
   QT_AggregateStats(sessions, profits, st);

   int h = FileOpen(fileName, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   if(h != INVALID_HANDLE)
      FileWrite(h, "session", "trades", "wins", "losses", "winrate", "net_usd");
   PrintFormat("=== QT REPORT %s ===", sym);
   for(int k=0; k<5; k++)
     {
      string name = (k < 4) ? QT_SessionName((QTSession)k) : "TOTAL";
      PrintFormat("%-7s trades=%d wins=%d losses=%d winrate=%.1f%% net=%.2f",
                  name, st[k].trades, st[k].wins, st[k].losses, QT_WinRate(st[k]), st[k].net);
      if(h != INVALID_HANDLE)
         FileWrite(h, name, st[k].trades, st[k].wins, st[k].losses,
                   DoubleToString(QT_WinRate(st[k]), 1), DoubleToString(st[k].net, 2));
     }
   if(h != INVALID_HANDLE) FileClose(h);
  }

#endif
