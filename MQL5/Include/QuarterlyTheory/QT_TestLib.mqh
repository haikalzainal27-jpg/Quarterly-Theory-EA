//+------------------------------------------------------------------+
//| QT_TestLib.mqh - minimal assert helpers for script-based tests   |
//+------------------------------------------------------------------+
#ifndef QT_TESTLIB_MQH
#define QT_TESTLIB_MQH

int g_qtPassed = 0;
int g_qtFailed = 0;

void QT_AssertTrue(bool c, string name)
  {
   if(c) g_qtPassed++;
   else { g_qtFailed++; PrintFormat("FAIL: %s", name); }
  }

void QT_AssertEqInt(long exp, long act, string name)
  {
   if(exp==act) g_qtPassed++;
   else { g_qtFailed++; PrintFormat("FAIL: %s expected=%I64d actual=%I64d", name, exp, act); }
  }

void QT_AssertEqDbl(double exp, double act, double eps, string name)
  {
   if(MathAbs(exp-act)<=eps) g_qtPassed++;
   else { g_qtFailed++; PrintFormat("FAIL: %s expected=%.10f actual=%.10f", name, exp, act); }
  }

void QT_AssertEqTime(datetime exp, datetime act, string name)
  {
   if(exp==act) g_qtPassed++;
   else { g_qtFailed++; PrintFormat("FAIL: %s expected=%s actual=%s", name,
                                    TimeToString(exp,TIME_DATE|TIME_SECONDS),
                                    TimeToString(act,TIME_DATE|TIME_SECONDS)); }
  }

void QT_TestSummary()
  {
   PrintFormat("QT TESTS: %d passed, %d failed", g_qtPassed, g_qtFailed);
  }

#endif
