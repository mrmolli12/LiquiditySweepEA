//+------------------------------------------------------------------+
//| AccountGuard.mqh - account-wide risk locks. If any check fails,   |
//| the EA must not trade, full stop.                                  |
//+------------------------------------------------------------------+
#ifndef __LSEA_ACCOUNTGUARD_MQH__
#define __LSEA_ACCOUNTGUARD_MQH__

class CAccountGuard
{
private:
   double   m_dayStartEquity;
   double   m_dayStartBalance;
   double   m_peakEquity;
   datetime m_currentDay;
   int      m_dailyTrades;
   int      m_consecutiveLosses;

public:
   CAccountGuard(void)
   {
      m_dayStartEquity   = AccountInfoDouble(ACCOUNT_EQUITY);
      m_dayStartBalance  = AccountInfoDouble(ACCOUNT_BALANCE);
      m_peakEquity       = AccountInfoDouble(ACCOUNT_EQUITY);
      m_currentDay       = 0;
      m_dailyTrades      = 0;
      m_consecutiveLosses= 0;
   }

   void OnTick()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      dt.hour = 0; dt.min = 0; dt.sec = 0;
      datetime today = StructToTime(dt);

      if(today != m_currentDay)
      {
         m_currentDay      = today;
         m_dayStartEquity  = AccountInfoDouble(ACCOUNT_EQUITY);
         m_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
         m_dailyTrades     = 0;
      }

      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      if(eq > m_peakEquity) m_peakEquity = eq;
   }

   void RegisterTradeOpened()  { m_dailyTrades++; }
   void RegisterTradeResult(bool wasLoss)
   {
      if(wasLoss) m_consecutiveLosses++;
      else        m_consecutiveLosses = 0;
   }

   double DailyLossUsd()     { return m_dayStartEquity - AccountInfoDouble(ACCOUNT_EQUITY); }
   double DailyLossPercent() { return (m_dayStartEquity > 0) ? (DailyLossUsd() / m_dayStartEquity) * 100.0 : 0.0; }
   double DrawdownPercent()  { return (m_peakEquity > 0) ? ((m_peakEquity - AccountInfoDouble(ACCOUNT_EQUITY)) / m_peakEquity) * 100.0 : 0.0; }
   int    DailyTrades()      { return m_dailyTrades; }
   int    ConsecutiveLosses(){ return m_consecutiveLosses; }

   //--- Master check. Fills reasonOut with a human-readable explanation on failure.
   bool IsTradingAllowed(bool killSwitch, double maxDailyLossUsd, double maxDailyLossPercent,
                          double maxAccountDrawdownPercent, int maxDailyTrades,
                          int maxConsecutiveLosses, int maxOpenPositions, int currentOpenPositions,
                          string &reasonOut)
   {
      if(killSwitch)                                            { reasonOut = "Emergency kill switch is ON";              return false; }
      if(maxDailyLossUsd > 0 && DailyLossUsd() >= maxDailyLossUsd)          { reasonOut = "Max daily loss (USD) reached";  return false; }
      if(maxDailyLossPercent > 0 && DailyLossPercent() >= maxDailyLossPercent) { reasonOut = "Max daily loss (%) reached"; return false; }
      if(maxAccountDrawdownPercent > 0 && DrawdownPercent() >= maxAccountDrawdownPercent) { reasonOut = "Max account drawdown reached"; return false; }
      if(maxDailyTrades > 0 && m_dailyTrades >= maxDailyTrades)  { reasonOut = "Max daily trades reached";                return false; }
      if(maxConsecutiveLosses > 0 && m_consecutiveLosses >= maxConsecutiveLosses) { reasonOut = "Max consecutive losses reached"; return false; }
      if(maxOpenPositions > 0 && currentOpenPositions >= maxOpenPositions) { reasonOut = "Max open positions reached";    return false; }

      reasonOut = "OK";
      return true;
   }
};

#endif // __LSEA_ACCOUNTGUARD_MQH__
