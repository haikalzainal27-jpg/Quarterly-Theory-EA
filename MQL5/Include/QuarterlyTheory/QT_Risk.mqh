//+------------------------------------------------------------------+
//| QT_Risk.mqh - fixed-dollar lot sizing and scalping/daily filters  |
//+------------------------------------------------------------------+
#ifndef QT_RISK_MQH
#define QT_RISK_MQH

#include "QT_Types.mqh"

// Lot so that hitting SL loses riskUSD. Rounded DOWN to volStep.
// Returns 0 when below volMin (never rounds up -> never risks more than riskUSD).
double QT_CalcLot(double riskUSD, double slDistPrice, double tickValue, double tickSize,
                  double volMin, double volStep)
  {
   if(riskUSD <= 0 || slDistPrice <= 0 || tickValue <= 0 || tickSize <= 0 || volStep <= 0)
      return 0.0;
   double lossPerLot = slDistPrice / tickSize * tickValue;
   double raw  = riskUSD / lossPerLot;
   double lots = MathFloor(raw / volStep + 1e-9) * volStep;
   int digits  = (int)MathMax(0, MathCeil(-MathLog10(volStep) - 1e-9));
   lots = NormalizeDouble(lots, digits);
   if(lots < volMin - 1e-12) return 0.0;
   return lots;
  }

QTSkip QT_CheckScalpFilters(double slDistPoints, double spreadPoints, double lot,
                            double minSLSpreadMult, double maxSpreadPoints, double maxLot)
  {
   if(spreadPoints > maxSpreadPoints)               return SKIP_SPREAD;
   if(slDistPoints < minSLSpreadMult*spreadPoints)  return SKIP_SL_TOO_SMALL;
   if(lot <= 0.0)                                   return SKIP_LOT_MIN;
   if(lot > maxLot + 1e-12)                         return SKIP_LOT_MAX;
   return SKIP_NONE;
  }

QTSkip QT_CheckDailyLimits(double realisedTodayUSD, int tradesToday, int tradesThisCycle,
                           double dailyLossUSD, int maxPerDay, int maxPerCycle)
  {
   if(realisedTodayUSD <= -dailyLossUSD + 1e-9) return SKIP_DAILY_LOSS;
   if(tradesToday >= maxPerDay)                 return SKIP_MAX_DAY;
   if(tradesThisCycle >= maxPerCycle)           return SKIP_MAX_CYCLE;
   return SKIP_NONE;
  }

string QT_SkipName(QTSkip s)
  {
   switch(s)
     {
      case SKIP_NONE:         return "NONE";
      case SKIP_SL_TOO_SMALL: return "SL_TOO_SMALL";
      case SKIP_SPREAD:       return "SPREAD";
      case SKIP_LOT_MIN:      return "LOT_MIN";
      case SKIP_LOT_MAX:      return "LOT_MAX";
      case SKIP_DAILY_LOSS:   return "DAILY_LOSS";
      case SKIP_MAX_DAY:      return "MAX_DAY";
      case SKIP_MAX_CYCLE:    return "MAX_CYCLE";
      case SKIP_TO_FILTER:    return "TO_FILTER";
      case SKIP_SESSION_OFF:  return "SESSION_OFF";
     }
   return "?";
  }

#endif
