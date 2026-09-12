//+------------------------------------------------------------------+
//| LiquiditySweep.mqh - detects a valid liquidity sweep of an H1     |
//| fractal level, using closed M5 bars for reactive detection.       |
//+------------------------------------------------------------------+
#ifndef __LSEA_LIQUIDITYSWEEP_MQH__
#define __LSEA_LIQUIDITYSWEEP_MQH__

#include "Definitions.mqh"

class CLiquiditySweep
{
private:
   double m_minPenetrationPoints;
   bool   m_requireCloseBack;
   int    m_maxAgeH1Bars;

public:
   CLiquiditySweep(void)
   {
      m_minPenetrationPoints = 20;
      m_requireCloseBack     = true;
      m_maxAgeH1Bars         = 48;
   }

   void Configure(double minPenetrationPoints, bool requireCloseBack, int maxAgeH1Bars)
   {
      m_minPenetrationPoints = minPenetrationPoints;
      m_requireCloseBack     = requireCloseBack;
      m_maxAgeH1Bars         = maxAgeH1Bars;
   }

   // fractal age check - returns false (expired) if the fractal is older than
   // m_maxAgeH1Bars H1 bars and no sweep has happened yet.
   bool IsFractalExpired(const string symbol, datetime fractalTime)
   {
      int barsElapsed = iBarShift(symbol, PERIOD_H1, fractalTime, false);
      return (barsElapsed > m_maxAgeH1Bars);
   }

   //--- Checks the most recently CLOSED M5 bar for a sweep below fractalLow.
   //--- Returns true once, on the bar where the sweep is confirmed.
   bool CheckSweepBelow(const string symbol, double fractalLow, datetime &sweepTimeOut)
   {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double low1  = iLow(symbol, PERIOD_M5, 1);
      double close1= iClose(symbol, PERIOD_M5, 1);
      if(low1 == 0.0) return false;

      bool penetrated = (fractalLow - low1) >= (m_minPenetrationPoints * point);
      if(!penetrated) return false;

      if(m_requireCloseBack && close1 <= fractalLow) return false; // wick must close back above

      sweepTimeOut = iTime(symbol, PERIOD_M5, 1);
      return true;
   }

   bool CheckSweepAbove(const string symbol, double fractalHigh, datetime &sweepTimeOut)
   {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double high1 = iHigh(symbol, PERIOD_M5, 1);
      double close1= iClose(symbol, PERIOD_M5, 1);
      if(high1 == 0.0) return false;

      bool penetrated = (high1 - fractalHigh) >= (m_minPenetrationPoints * point);
      if(!penetrated) return false;

      if(m_requireCloseBack && close1 >= fractalHigh) return false;

      sweepTimeOut = iTime(symbol, PERIOD_M5, 1);
      return true;
   }
};

#endif // __LSEA_LIQUIDITYSWEEP_MQH__
