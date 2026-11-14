//+------------------------------------------------------------------+
//| QT_Types.mqh - shared enums and structs for Quarterly Theory EA  |
//+------------------------------------------------------------------+
#ifndef QT_TYPES_MQH
#define QT_TYPES_MQH

#define QT_SEC_90M    5400
#define QT_SEC_MICRO  1350
#define QT_SEC_SESS   21600
#define QT_SEC_DAY    86400

enum QTSession   { QT_ASIA=0, QT_LONDON=1, QT_NYAM=2, QT_NYPM=3 };
enum QTTimeMode  { TIME_NY_PLUS_7=0, TIME_MANUAL_GMT=1 };
enum QTModelLevel{ MODEL_SESSION_90M=0, MODEL_CYCLE_MICRO=1 };
enum QTDir       { DIR_NONE=0, DIR_BUY=1, DIR_SELL=-1 };

enum QTSkip
  {
   SKIP_NONE=0,
   SKIP_SL_TOO_SMALL,
   SKIP_SPREAD,
   SKIP_LOT_MIN,
   SKIP_LOT_MAX,
   SKIP_DAILY_LOSS,
   SKIP_MAX_DAY,
   SKIP_MAX_CYCLE,
   SKIP_TO_FILTER,
   SKIP_SESSION_OFF
  };

struct QTRange
  {
   bool     valid;
   double   high;
   double   low;
   datetime highTime;
   datetime lowTime;
  };

struct QTCyclePos
  {
   datetime   nyTime;
   datetime   tradingDayStartNY; // 18:00 NY that started this trading day
   QTSession  session;
   datetime   sessionStartNY;
   int        cycle90Idx;        // 0..3 within session
   datetime   cycle90StartNY;
   int        microIdx;          // 0..3 within 90-min cycle
   datetime   frameStartNY;      // start of the 4-quarter model frame
   int        frameQuarter;      // 0..3 = Q1..Q4 of the model frame
   int        frameQuarterSec;   // length of one frame quarter (5400 or 1350)
  };

string QT_SessionName(QTSession s)
  {
   switch(s)
     {
      case QT_ASIA:   return "ASIA";
      case QT_LONDON: return "LONDON";
      case QT_NYAM:   return "NYAM";
      case QT_NYPM:   return "NYPM";
     }
   return "?";
  }

#endif
