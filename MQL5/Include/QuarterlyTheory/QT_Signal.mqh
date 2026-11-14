//+------------------------------------------------------------------+
//| QT_Signal.mqh - combine AMDX + SSMT + True Open + MSS into signal |
//| Pure: all data is passed in.                                       |
//+------------------------------------------------------------------+
#ifndef QT_SIGNAL_MQH
#define QT_SIGNAL_MQH

#include "QT_Types.mqh"
#include "QT_SSMT.mqh"
#include "QT_TrueOpen.mqh"
#include "QT_Structure.mqh"

struct QTSignalInput
  {
   QTCyclePos pos;
   QTRange    mainQ1, mainQ2, pairQ1, pairQ2; // times are SERVER time
   datetime   q3StartServer;                  // start of frame Q3 (server time)
   double     toDaily, toSession, toCycle;    // True Open prices
   bool       toDailyFormed, toSessionFormed, toCycleFormed;
   double     bid, ask;
   bool       useSSMT, useTO, useMSS;
  };

struct QTSignal
  {
   QTDir  dir;
   double entry, sl, tp;
   double sweepExtreme;
   QTSkip skip;
   string reason;
  };

void QT_SignalReset(QTSignal &s)
  {
   s.dir = DIR_NONE; s.entry = 0; s.sl = 0; s.tp = 0; s.sweepExtreme = 0;
   s.skip = SKIP_NONE; s.reason = "";
  }

// m1: CLOSED main-symbol M1 bars, oldest -> newest, covering at least Q2..now.
void QT_BuildSignal(const QTSignalInput &in, const MqlRates &m1[], double slBufferPrice, QTSignal &s)
  {
   QT_SignalReset(s);

   if(in.pos.frameQuarter != 2) { s.reason = "not_q3"; return; }

   // 1) Direction from Q2 manipulation (+ SSMT)
   QTDir dir = in.useSSMT ? QT_DetectSSMT(in.mainQ1, in.mainQ2, in.pairQ1, in.pairQ2)
                          : QT_SweepDirection(in.mainQ1, in.mainQ2);
   if(dir == DIR_NONE) { s.reason = in.useSSMT ? "no_ssmt" : "no_sweep"; return; }

   double   sweep     = (dir == DIR_BUY) ? in.mainQ2.low     : in.mainQ2.high;
   datetime sweepTime = (dir == DIR_BUY) ? in.mainQ2.lowTime : in.mainQ2.highTime;
   s.sweepExtreme = sweep;

   // 2) Invalidation: price traded beyond the sweep extreme during Q3
   int n = ArraySize(m1);
   for(int i=0; i<n; i++)
     {
      if(m1[i].time < in.q3StartServer) continue;
      if(dir == DIR_BUY  && m1[i].low  < sweep) { s.reason = "invalidated"; return; }
      if(dir == DIR_SELL && m1[i].high > sweep) { s.reason = "invalidated"; return; }
     }
   if(dir == DIR_BUY  && in.bid < sweep) { s.reason = "invalidated"; return; }
   if(dir == DIR_SELL && in.ask > sweep) { s.reason = "invalidated"; return; }

   // 3) M1 market structure shift after the sweep
   if(in.useMSS)
     {
      double lvl;
      if(!QT_DetectMSS(m1, dir, sweepTime, lvl)) { s.reason = "no_mss"; return; }
     }

   double entry = (dir == DIR_BUY) ? in.ask : in.bid;

   // 4) True Open premium/discount filter (>= 2 formed TOs agree)
   if(in.useTO)
     {
      double tp[3]; bool tf[3];
      tp[0] = in.toDaily;   tf[0] = in.toDailyFormed;
      tp[1] = in.toSession; tf[1] = in.toSessionFormed;
      tp[2] = in.toCycle;   tf[2] = in.toCycleFormed;
      if(!QT_TrueOpenPass(dir, entry, tp, tf, 2))
        {
         s.skip = SKIP_TO_FILTER; s.reason = "to_filter"; return;
        }
     }

   // 5) SL beyond sweep, TP = 1:1
   double sl = (dir == DIR_BUY) ? sweep - slBufferPrice : sweep + slBufferPrice;
   double dist = MathAbs(entry - sl);
   if(dist <= 0.0) { s.reason = "zero_sl"; return; }

   s.dir   = dir;
   s.entry = entry;
   s.sl    = sl;
   s.tp    = (dir == DIR_BUY) ? entry + dist : entry - dist;
   s.reason = "ok";
  }

#endif
