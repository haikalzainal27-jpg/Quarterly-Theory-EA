//+------------------------------------------------------------------+
//| QT_Data.mqh - terminal data access (M1 bars, prices)              |
//+------------------------------------------------------------------+
#ifndef QT_DATA_MQH
#define QT_DATA_MQH

// M1 bars with time in [fromServer, toServer], ordered oldest -> newest.
bool QT_LoadM1(string sym, datetime fromServer, datetime toServer, MqlRates &out[])
  {
   ArrayFree(out);
   ArraySetAsSeries(out, false);
   if(toServer < fromServer) return false;
   int got = CopyRates(sym, PERIOD_M1, fromServer, toServer, out);
   return (got > 0);
  }

// Open price of the first M1 bar at or after the given server time. 0 if none.
double QT_PriceAt(string sym, datetime server)
  {
   MqlRates r[];
   ArraySetAsSeries(r, false);
   int got = CopyRates(sym, PERIOD_M1, server, server + 3600, r);
   for(int i=0; i<got; i++)
      if(r[i].time >= server) return r[i].open;
   return 0.0;
  }

#endif
