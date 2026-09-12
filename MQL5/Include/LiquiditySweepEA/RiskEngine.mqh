//+------------------------------------------------------------------+
//| RiskEngine.mqh - broker-aware position sizing and pre-trade       |
//| validation. Never assumes a fixed pip value across all symbols.   |
//+------------------------------------------------------------------+
#ifndef __LSEA_RISKENGINE_MQH__
#define __LSEA_RISKENGINE_MQH__

#include "Definitions.mqh"
#include "Logger.mqh"

class CRiskEngine
{
private:
   CLogger *m_log;

public:
   void SetLogger(CLogger *log) { m_log = log; }

   //--- Computes a valid lot size for a given SL distance (in price units)
   //--- and a target risk model. Returns 0.0 if it cannot produce a safe size.
   double CalculateLotSize(const string symbol, ENUM_RISK_MODEL model, double fixedLot,
                            double riskUsd, double riskPercent, double slDistancePrice)
   {
      if(slDistancePrice <= 0.0)
      {
         if(m_log != NULL) m_log.Error("RiskEngine: SL distance is zero/negative - refusing to size trade.");
         return 0.0;
      }

      double lot = 0.0;

      if(model == RISK_FIXED_LOT)
      {
         lot = fixedLot;
      }
      else
      {
         double riskMoney = 0.0;
         if(model == RISK_FIXED_USD)
            riskMoney = riskUsd;
         else if(model == RISK_PERCENT_BALANCE)
            riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * (riskPercent / 100.0);
         else if(model == RISK_PERCENT_EQUITY)
            riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * (riskPercent / 100.0);

         double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
         double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
         if(tickSize <= 0.0 || tickValue <= 0.0)
         {
            if(m_log != NULL) m_log.Error("RiskEngine: could not read tick size/value for " + symbol);
            return 0.0;
         }

         double valuePerPriceUnit = tickValue / tickSize;      // account-currency value of 1.0 price move, per 1 lot
         double lossPerLot        = slDistancePrice * valuePerPriceUnit;
         if(lossPerLot <= 0.0)
         {
            if(m_log != NULL) m_log.Error("RiskEngine: computed loss-per-lot is zero - refusing to size trade.");
            return 0.0;
         }

         lot = riskMoney / lossPerLot;
      }

      return NormalizeVolume(symbol, lot);
   }

   double NormalizeVolume(const string symbol, double lot)
   {
      double minVol  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxVol  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double step    = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      if(step <= 0.0) step = minVol > 0 ? minVol : 0.01;

      lot = MathFloor(lot / step) * step;
      if(lot < minVol) lot = minVol;
      if(lot > maxVol) lot = maxVol;

      int digits = 2;
      if(step < 0.01) digits = 3;
      return NormalizeDouble(lot, digits);
   }

   //--- Full pre-trade validation. Returns true only if the trade is safe to send.
   bool ValidateTrade(const string symbol, ENUM_ORDER_TYPE orderType, double entry, double sl, double tp,
                       double lot, string &rejectReasonOut)
   {
      if(!SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE)) { /* handled below */ }

      long tradeMode = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
      if(tradeMode == SYMBOL_TRADE_MODE_DISABLED)
      {
         rejectReasonOut = "Symbol trading disabled by broker";
         return false;
      }

      double minVol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxVol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      if(lot < minVol || lot > maxVol || lot <= 0.0)
      {
         rejectReasonOut = StringFormat("Volume %.2f outside broker range [%.2f, %.2f]", lot, minVol, maxVol);
         return false;
      }

      long stopsLevelPoints = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double minStopsDist = stopsLevelPoints * point;

      if(MathAbs(entry - sl) < minStopsDist || MathAbs(entry - tp) < minStopsDist)
      {
         rejectReasonOut = StringFormat("SL/TP closer than broker's minimum stop distance (%d points)", (int)stopsLevelPoints);
         return false;
      }

      double marginRequired = 0.0;
      if(!OrderCalcMargin(orderType, symbol, lot, entry, marginRequired))
      {
         rejectReasonOut = "OrderCalcMargin failed";
         return false;
      }

      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(marginRequired > freeMargin)
      {
         rejectReasonOut = StringFormat("Insufficient free margin (needs %.2f, have %.2f)", marginRequired, freeMargin);
         return false;
      }

      return true;
   }
};

#endif // __LSEA_RISKENGINE_MQH__
