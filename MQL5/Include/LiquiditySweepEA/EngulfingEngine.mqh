//+------------------------------------------------------------------+
//| EngulfingEngine.mqh - M5 bullish/bearish engulfing detection      |
//+------------------------------------------------------------------+
#ifndef __LSEA_ENGULFINGENGINE_MQH__
#define __LSEA_ENGULFINGENGINE_MQH__

#include "Definitions.mqh"

class CEngulfingEngine
{
private:
   double m_minBodyPoints;
   double m_minRangePoints;
   double m_minBodyPercentage; // body/range, 0..1
   int    m_maxBarsToWait;     // how many M5 bars after the sweep to keep watching

public:
   CEngulfingEngine(void)
   {
      m_minBodyPoints     = 30;
      m_minRangePoints    = 40;
      m_minBodyPercentage = 0.55;
      m_maxBarsToWait     = 24; // 2 hours on M5
   }

   void Configure(double minBodyPoints, double minRangePoints, double minBodyPercentage, int maxBarsToWait)
   {
      m_minBodyPoints     = minBodyPoints;
      m_minRangePoints    = minRangePoints;
      m_minBodyPercentage = minBodyPercentage;
      m_maxBarsToWait     = maxBarsToWait;
   }

   bool TimedOut(const string symbol, datetime sweepTime)
   {
      int bars = iBarShift(symbol, PERIOD_M5, sweepTime, false);
      return (bars > m_maxBarsToWait);
   }

   // Bullish engulfing on the last CLOSED M5 bar (shift 1) engulfing bar shift 2.
   bool CheckBullish(const string symbol, double &openOut, double &closeOut, double &highOut, double &lowOut, datetime &timeOut)
   {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

      double o1 = iOpen(symbol, PERIOD_M5, 1);
      double c1 = iClose(symbol, PERIOD_M5, 1);
      double h1 = iHigh(symbol, PERIOD_M5, 1);
      double l1 = iLow(symbol, PERIOD_M5, 1);
      double o2 = iOpen(symbol, PERIOD_M5, 2);
      double c2 = iClose(symbol, PERIOD_M5, 2);
      if(o1 == 0.0 || o2 == 0.0) return false;

      bool candle1Bullish = c1 > o1;
      bool candle2Bearish = c2 < o2;
      bool engulfsBody    = (o1 <= c2) && (c1 >= o2);

      double body  = MathAbs(c1 - o1);
      double range = h1 - l1;
      if(range <= 0.0) return false;

      bool sizeOk = (body >= m_minBodyPoints * point) &&
                    (range >= m_minRangePoints * point) &&
                    ((body / range) >= m_minBodyPercentage);

      if(candle1Bullish && candle2Bearish && engulfsBody && sizeOk)
      {
         openOut  = o1; closeOut = c1; highOut = h1; lowOut = l1;
         timeOut  = iTime(symbol, PERIOD_M5, 1);
         return true;
      }
      return false;
   }

   bool CheckBearish(const string symbol, double &openOut, double &closeOut, double &highOut, double &lowOut, datetime &timeOut)
   {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

      double o1 = iOpen(symbol, PERIOD_M5, 1);
      double c1 = iClose(symbol, PERIOD_M5, 1);
      double h1 = iHigh(symbol, PERIOD_M5, 1);
      double l1 = iLow(symbol, PERIOD_M5, 1);
      double o2 = iOpen(symbol, PERIOD_M5, 2);
      double c2 = iClose(symbol, PERIOD_M5, 2);
      if(o1 == 0.0 || o2 == 0.0) return false;

      bool candle1Bearish = c1 < o1;
      bool candle2Bullish = c2 > o2;
      bool engulfsBody     = (o1 >= c2) && (c1 <= o2);

      double body  = MathAbs(c1 - o1);
      double range = h1 - l1;
      if(range <= 0.0) return false;

      bool sizeOk = (body >= m_minBodyPoints * point) &&
                    (range >= m_minRangePoints * point) &&
                    ((body / range) >= m_minBodyPercentage);

      if(candle1Bearish && candle2Bullish && engulfsBody && sizeOk)
      {
         openOut  = o1; closeOut = c1; highOut = h1; lowOut = l1;
         timeOut  = iTime(symbol, PERIOD_M5, 1);
         return true;
      }
      return false;
   }
};

#endif // __LSEA_ENGULFINGENGINE_MQH__
