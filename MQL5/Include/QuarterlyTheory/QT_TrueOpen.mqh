//+------------------------------------------------------------------+
//| QT_TrueOpen.mqh - Daily / Session / 90-min True Open              |
//+------------------------------------------------------------------+
#ifndef QT_TRUEOPEN_MQH
#define QT_TRUEOPEN_MQH

#include "QT_Types.mqh"

// All returned times are New York time.
//  dailyTO   = 00:00 NY (start of Q2 of the trading day)
//  sessionTO = session start + 90 min (start of session Q2)
//  cycleTO   = 90-min cycle start + 22.5 min (start of micro Q2)
void QT_TrueOpenTimesNY(const QTCyclePos &p, datetime &dailyTO, datetime &sessionTO, datetime &cycleTO)
  {
   dailyTO   = p.tradingDayStartNY + 6*3600;
   sessionTO = p.sessionStartNY + QT_SEC_90M;
   cycleTO   = p.cycle90StartNY + QT_SEC_MICRO;
  }

// Number of formed True Opens that agree with the direction.
// Buy needs price below the TO (discount), sell needs price above (premium).
int QT_TrueOpenVotes(QTDir dir, double price, const double &toPrices[], const bool &toFormed[])
  {
   int votes = 0;
   int n = (int)MathMin(ArraySize(toPrices), ArraySize(toFormed));
   for(int i=0; i<n; i++)
     {
      if(!toFormed[i] || toPrices[i] <= 0.0) continue;
      if(dir == DIR_BUY  && price < toPrices[i]) votes++;
      if(dir == DIR_SELL && price > toPrices[i]) votes++;
     }
   return votes;
  }

bool QT_TrueOpenPass(QTDir dir, double price, const double &toPrices[], const bool &toFormed[], int minVotes=2)
  {
   if(dir == DIR_NONE) return false;
   return QT_TrueOpenVotes(dir, price, toPrices, toFormed) >= minVotes;
  }

#endif
