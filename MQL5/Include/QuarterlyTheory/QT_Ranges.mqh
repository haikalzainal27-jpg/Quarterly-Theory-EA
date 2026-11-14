//+------------------------------------------------------------------+
//| QT_Ranges.mqh - high/low of a time window from M1 bars            |
//+------------------------------------------------------------------+
#ifndef QT_RANGES_MQH
#define QT_RANGES_MQH

#include "QT_Types.mqh"

// Range of all bars with time in [fromServer, toServerExclusive).
// Works regardless of array ordering. valid=false when no bar falls inside.
QTRange QT_RangeBetween(const MqlRates &rates[], datetime fromServer, datetime toServerExclusive)
  {
   QTRange r;
   ZeroMemory(r);
   r.valid = false;
   int n = ArraySize(rates);
   for(int i=0; i<n; i++)
     {
      datetime t = rates[i].time;
      if(t < fromServer || t >= toServerExclusive) continue;
      if(!r.valid)
        {
         r.valid = true;
         r.high = rates[i].high; r.highTime = t;
         r.low  = rates[i].low;  r.lowTime  = t;
         continue;
        }
      if(rates[i].high > r.high) { r.high = rates[i].high; r.highTime = t; }
      if(rates[i].low  < r.low)  { r.low  = rates[i].low;  r.lowTime  = t; }
     }
   return r;
  }

#endif
