//+------------------------------------------------------------------+
//| QT_BB.mqh - Bollinger Bands re-entry signal (pure functions)      |
//| closes[] is ordered oldest -> newest, CLOSED bars only.           |
//+------------------------------------------------------------------+
#ifndef QT_BB_MQH
#define QT_BB_MQH

#include "QT_Types.mqh"

// Bands over closes[endIdx-period+1 .. endIdx] (population std dev, like iBands).
bool QT_BBCalc(const double &closes[], int endIdx, int period, double dev,
               double &mid, double &upper, double &lower)
  {
   mid = 0; upper = 0; lower = 0;
   if(period < 2 || endIdx - period + 1 < 0 || endIdx >= ArraySize(closes)) return false;
   double sum = 0;
   for(int i=endIdx-period+1; i<=endIdx; i++) sum += closes[i];
   mid = sum / period;
   double var = 0;
   for(int i=endIdx-period+1; i<=endIdx; i++) var += (closes[i]-mid)*(closes[i]-mid);
   double sd = MathSqrt(var / period);
   upper = mid + dev*sd;
   lower = mid - dev*sd;
   return true;
  }

// Re-entry: previous bar closed OUTSIDE its band, last bar closed back INSIDE.
//  below lower then back inside -> BUY ; above upper then back inside -> SELL
QTDir QT_BBReentrySignal(const double &closes[], int period, double dev)
  {
   int n = ArraySize(closes);
   if(n < period + 1) return DIR_NONE;
   double m1, u1, l1, m2, u2, l2;
   if(!QT_BBCalc(closes, n-2, period, dev, m1, u1, l1)) return DIR_NONE;
   if(!QT_BBCalc(closes, n-1, period, dev, m2, u2, l2)) return DIR_NONE;
   if(closes[n-2] < l1 && closes[n-1] > l2) return DIR_BUY;
   if(closes[n-2] > u1 && closes[n-1] < u2) return DIR_SELL;
   return DIR_NONE;
  }

// Price distance at which a fixed lot loses exactly riskUSD.
double QT_FixedRiskDistance(double riskUSD, double lot, double tickValue, double tickSize)
  {
   if(riskUSD <= 0 || lot <= 0 || tickValue <= 0 || tickSize <= 0) return 0.0;
   return riskUSD / (lot * tickValue / tickSize);
  }

#endif
