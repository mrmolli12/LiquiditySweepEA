//+------------------------------------------------------------------+
//| FractalEngine.mqh - confirmed H1 fractal high/low detection       |
//+------------------------------------------------------------------+
#ifndef __LSEA_FRACTALENGINE_MQH__
#define __LSEA_FRACTALENGINE_MQH__

#include "Definitions.mqh"

class CFractalEngine
{
private:
   int m_period; // bars required on each side (2 = classic 5-bar fractal)

public:
   CFractalEngine(void) { m_period = 2; }
   void SetPeriod(int p) { m_period = MathMax(1, p); }

   //--- returns true and fills the values if a NEW confirmed fractal (more
   //--- recent than lastKnownTime) was found on the given symbol's H1 chart.
   bool FindLatestConfirmedHigh(const string symbol, double &level, datetime &barTime, int lookback = 200)
   {
      int n = m_period;
      for(int shift = n + 1; shift <= lookback; shift++)
      {
         double mid = iHigh(symbol, PERIOD_H1, shift);
         if(mid == 0.0) return false; // not enough history

         bool isFractal = true;
         for(int k = 1; k <= n && isFractal; k++)
         {
            if(iHigh(symbol, PERIOD_H1, shift - k) >= mid) isFractal = false; // newer side
            if(iHigh(symbol, PERIOD_H1, shift + k) >= mid) isFractal = false; // older side
         }
         if(isFractal)
         {
            level   = mid;
            barTime = iTime(symbol, PERIOD_H1, shift);
            return true;
         }
      }
      return false;
   }

   bool FindLatestConfirmedLow(const string symbol, double &level, datetime &barTime, int lookback = 200)
   {
      int n = m_period;
      for(int shift = n + 1; shift <= lookback; shift++)
      {
         double mid = iLow(symbol, PERIOD_H1, shift);
         if(mid == 0.0) return false;

         bool isFractal = true;
         for(int k = 1; k <= n && isFractal; k++)
         {
            if(iLow(symbol, PERIOD_H1, shift - k) <= mid) isFractal = false;
            if(iLow(symbol, PERIOD_H1, shift + k) <= mid) isFractal = false;
         }
         if(isFractal)
         {
            level   = mid;
            barTime = iTime(symbol, PERIOD_H1, shift);
            return true;
         }
      }
      return false;
   }
};

#endif // __LSEA_FRACTALENGINE_MQH__
