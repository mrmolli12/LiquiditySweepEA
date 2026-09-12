//+------------------------------------------------------------------+
//| ScoreEngine.mqh - configurable setup-quality score                |
//+------------------------------------------------------------------+
#ifndef __LSEA_SCOREENGINE_MQH__
#define __LSEA_SCOREENGINE_MQH__

class CScoreEngine
{
public:
   // Every "has..." flag is a boolean condition that was actually evaluated
   // upstream (never assumed true). maxPossible is computed from which
   // filters are enabled, so the grade is fair even when optional filters
   // are switched off.
   int Evaluate(bool sweepValid, bool engulfingValid, bool bosMssPassed, bool useBosMss,
                bool fvgPassed, bool useFvg, bool htfAligned, bool premiumDiscountOk, bool usePremiumDiscount,
                bool goodSession, bool lowSpread, bool volatilityOk, bool newsOk,
                int &maxPossibleOut, string &reasonsOut)
   {
      int score = 0, maxPossible = 0;
      string reasons = "";

      // mandatory-ish core (still scored, but these two must be true to even reach scoring)
      if(sweepValid)    { score += 2; reasons += "Sweep+2 "; } maxPossible += 2;
      if(engulfingValid){ score += 2; reasons += "Engulfing+2 "; } maxPossible += 2;

      if(useBosMss) { maxPossible += 2; if(bosMssPassed) { score += 2; reasons += "BOS/MSS+2 "; } }
      if(useFvg)    { maxPossible += 1; if(fvgPassed)    { score += 1; reasons += "FVG+1 "; } }

      maxPossible += 1; if(htfAligned) { score += 1; reasons += "HTF+1 "; }
      if(usePremiumDiscount) { maxPossible += 1; if(premiumDiscountOk) { score += 1; reasons += "PremDisc+1 "; } }

      maxPossible += 1; if(goodSession)   { score += 1; reasons += "Session+1 "; }
      maxPossible += 1; if(lowSpread)     { score += 1; reasons += "LowSpread+1 "; }
      maxPossible += 1; if(volatilityOk)  { score += 1; reasons += "Volatility+1 "; }
      maxPossible += 1; if(newsOk)        { score += 1; reasons += "NewsOK+1 "; }

      maxPossibleOut = maxPossible;
      reasonsOut     = reasons;
      return score;
   }

   string Grade(int score, int maxPossible)
   {
      if(maxPossible <= 0) return "N/A";
      double pct = (double)score / (double)maxPossible;
      if(pct >= 0.90) return "A+";
      if(pct >= 0.80) return "A";
      if(pct >= 0.70) return "B";
      if(pct >= 0.60) return "C";
      return "D";
   }
};

#endif // __LSEA_SCOREENGINE_MQH__
