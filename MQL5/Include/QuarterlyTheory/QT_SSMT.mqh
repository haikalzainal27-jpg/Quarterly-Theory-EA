//+------------------------------------------------------------------+
//| QT_SSMT.mqh - Sequential SMT divergence between correlated assets |
//+------------------------------------------------------------------+
#ifndef QT_SSMT_MQH
#define QT_SSMT_MQH

#include "QT_Types.mqh"

// Bullish: main sweeps its Q1 low in Q2, pair does NOT sweep its Q1 low.
// Bearish: main sweeps its Q1 high in Q2, pair does NOT sweep its Q1 high.
// Main sweeping both sides, or both signals true -> DIR_NONE.
QTDir QT_DetectSSMT(const QTRange &mainQ1, const QTRange &mainQ2,
                    const QTRange &pairQ1, const QTRange &pairQ2)
  {
   if(!mainQ1.valid || !mainQ2.valid || !pairQ1.valid || !pairQ2.valid)
      return DIR_NONE;

   bool mainSweptLow  = mainQ2.low  < mainQ1.low;
   bool mainSweptHigh = mainQ2.high > mainQ1.high;
   if(mainSweptLow && mainSweptHigh) return DIR_NONE;

   bool pairSweptLow  = pairQ2.low  < pairQ1.low;
   bool pairSweptHigh = pairQ2.high > pairQ1.high;

   bool bull = mainSweptLow  && !pairSweptLow;
   bool bear = mainSweptHigh && !pairSweptHigh;
   if(bull && !bear) return DIR_BUY;
   if(bear && !bull) return DIR_SELL;
   return DIR_NONE;
  }

// Direction from the swept side only (used when SSMT filter is off).
QTDir QT_SweepDirection(const QTRange &mainQ1, const QTRange &mainQ2)
  {
   if(!mainQ1.valid || !mainQ2.valid) return DIR_NONE;
   bool sl = mainQ2.low  < mainQ1.low;
   bool sh = mainQ2.high > mainQ1.high;
   if(sl && !sh) return DIR_BUY;
   if(sh && !sl) return DIR_SELL;
   return DIR_NONE;
  }

#endif
