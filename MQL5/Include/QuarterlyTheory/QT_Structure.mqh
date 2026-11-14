//+------------------------------------------------------------------+
//| QT_Structure.mqh - M1 fractals and market structure shift (MSS)   |
//| Arrays are ordered oldest -> newest and contain CLOSED bars only. |
//+------------------------------------------------------------------+
#ifndef QT_STRUCTURE_MQH
#define QT_STRUCTURE_MQH

#include "QT_Types.mqh"

// Strict 2-left / 2-right fractal.
bool QT_IsFractalHigh(const MqlRates &r[], int i)
  {
   int n = ArraySize(r);
   if(i < 2 || i > n-3) return false;
   double h = r[i].high;
   return (h > r[i-1].high && h > r[i-2].high && h > r[i+1].high && h > r[i+2].high);
  }

bool QT_IsFractalLow(const MqlRates &r[], int i)
  {
   int n = ArraySize(r);
   if(i < 2 || i > n-3) return false;
   double l = r[i].low;
   return (l < r[i-1].low && l < r[i-2].low && l < r[i+1].low && l < r[i+2].low);
  }

// True when the LAST bar is the first close beyond the most recent fractal
// (buy: fractal high, sell: fractal low) formed at or after afterTime.
bool QT_DetectMSS(const MqlRates &r[], QTDir dir, datetime afterTime, double &brokenLevel)
  {
   brokenLevel = 0.0;
   int n = ArraySize(r);
   if(n < 6 || dir == DIR_NONE) return false;
   int last = n-1;

   int f = -1;
   for(int i=last-3; i>=2; i--)
     {
      if(r[i].time < afterTime) break;
      bool isF = (dir == DIR_BUY) ? QT_IsFractalHigh(r, i) : QT_IsFractalLow(r, i);
      if(isF) { f = i; break; }
     }
   if(f < 0) return false;

   double level = (dir == DIR_BUY) ? r[f].high : r[f].low;

   // Must be the first close beyond the level.
   for(int j=f+1; j<last; j++)
     {
      if(dir == DIR_BUY  && r[j].close > level) return false;
      if(dir == DIR_SELL && r[j].close < level) return false;
     }
   bool broke = (dir == DIR_BUY) ? (r[last].close > level) : (r[last].close < level);
   if(broke) brokenLevel = level;
   return broke;
  }

#endif
