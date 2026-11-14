//+------------------------------------------------------------------+
//| QT_Time.mqh - server <-> New York time and cycle position         |
//| Pure functions: no terminal calls.                                |
//+------------------------------------------------------------------+
#ifndef QT_TIME_MQH
#define QT_TIME_MQH

#include "QT_Types.mqh"

// Date (00:00) of the n-th Sunday of a month.
datetime QT_NthSunday(int year, int month, int n)
  {
   MqlDateTime d;
   ZeroMemory(d);
   d.year = year; d.mon = month; d.day = 1;
   datetime first = StructToTime(d);
   MqlDateTime f;
   TimeToStruct(first, f);
   int firstSunday = 1 + (7 - f.day_of_week) % 7;
   d.day = firstSunday + 7*(n-1);
   return StructToTime(d);
  }

// US DST: from 2nd Sunday of March 02:00 EST (07:00 UTC)
// until 1st Sunday of November 02:00 EDT (06:00 UTC).
bool QT_IsUSDST(datetime utc)
  {
   MqlDateTime t;
   TimeToStruct(utc, t);
   datetime start = QT_NthSunday(t.year, 3, 2)  + 7*3600;
   datetime end   = QT_NthSunday(t.year, 11, 1) + 6*3600;
   return (utc >= start && utc < end);
  }

datetime QT_ServerToNY(datetime server, QTTimeMode mode, int gmtOffsetHours)
  {
   if(mode == TIME_NY_PLUS_7)
      return server - 7*3600;
   datetime utc = server - gmtOffsetHours*3600;
   return utc - (QT_IsUSDST(utc) ? 4 : 5)*3600;
  }

datetime QT_NYToServer(datetime ny, QTTimeMode mode, int gmtOffsetHours)
  {
   if(mode == TIME_NY_PLUS_7)
      return ny + 7*3600;
   datetime utc = ny + 4*3600;          // assume EDT
   if(!QT_IsUSDST(utc)) utc = ny + 5*3600; // otherwise EST
   return utc + gmtOffsetHours*3600;
  }

QTCyclePos QT_GetCyclePos(datetime ny, QTModelLevel level)
  {
   QTCyclePos p;
   ZeroMemory(p);
   p.nyTime = ny;

   // Shift so that 18:00 NY becomes 00:00 -> trading day boundary.
   long shifted   = (long)ny + 6*3600;
   long dayStartS = shifted - (shifted % QT_SEC_DAY);
   p.tradingDayStartNY = (datetime)(dayStartS - 6*3600);

   long secIntoDay = shifted - dayStartS;
   int  sess       = (int)(secIntoDay / QT_SEC_SESS);
   p.session        = (QTSession)sess;
   p.sessionStartNY = p.tradingDayStartNY + sess*QT_SEC_SESS;

   long secIntoSess = secIntoDay % QT_SEC_SESS;
   p.cycle90Idx     = (int)(secIntoSess / QT_SEC_90M);
   p.cycle90StartNY = p.sessionStartNY + p.cycle90Idx*QT_SEC_90M;

   long secInto90 = secIntoSess % QT_SEC_90M;
   p.microIdx     = (int)(secInto90 / QT_SEC_MICRO);

   if(level == MODEL_SESSION_90M)
     {
      p.frameStartNY    = p.sessionStartNY;
      p.frameQuarter    = p.cycle90Idx;
      p.frameQuarterSec = QT_SEC_90M;
     }
   else
     {
      p.frameStartNY    = p.cycle90StartNY;
      p.frameQuarter    = p.microIdx;
      p.frameQuarterSec = QT_SEC_MICRO;
     }
   return p;
  }

// NY time at which open positions of this frame must be closed:
// end of frame Q4, but never later than 17:00 NY (daily market break),
// minus a safety buffer in minutes.
datetime QT_ForceCloseTimeNY(const QTCyclePos &p, int bufferMin)
  {
   datetime frameEnd = p.frameStartNY + 4*p.frameQuarterSec;
   datetime dayBreak = p.tradingDayStartNY + 23*3600; // 17:00 NY
   datetime end = (frameEnd < dayBreak) ? frameEnd : dayBreak;
   return end - bufferMin*60;
  }

#endif
