//+------------------------------------------------------------------+
//| ExecutionEngine.mqh - places/cancels orders, checks retcodes,     |
//| never fakes success.                                               |
//+------------------------------------------------------------------+
#ifndef __LSEA_EXECUTIONENGINE_MQH__
#define __LSEA_EXECUTIONENGINE_MQH__

#include <Trade\Trade.mqh>
#include "Logger.mqh"

class CExecutionEngine
{
private:
   CTrade   m_trade;
   CLogger *m_log;

public:
   void Init(ulong magic, ulong deviationPoints, CLogger *log)
   {
      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetDeviationInPoints(deviationPoints);
      m_trade.SetTypeFillingBySymbol(_Symbol);
      m_log = log;
   }

   bool PlaceBuyLimit(const string symbol, double volume, double price, double sl, double tp,
                       string comment, ulong &ticketOut)
   {
      bool ok = m_trade.BuyLimit(volume, price, symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
      if(!ok)
      {
         if(m_log != NULL) m_log.Error(StringFormat("BuyLimit failed for %s: retcode=%d (%s)",
                              symbol, m_trade.ResultRetcode(), m_trade.ResultRetcodeDescription()));
         return false;
      }
      ticketOut = m_trade.ResultOrder();
      if(m_log != NULL) m_log.Info(StringFormat("BuyLimit placed: %s vol=%.2f price=%.5f sl=%.5f tp=%.5f ticket=%I64u",
                           symbol, volume, price, sl, tp, ticketOut));
      return true;
   }

   bool PlaceSellLimit(const string symbol, double volume, double price, double sl, double tp,
                        string comment, ulong &ticketOut)
   {
      bool ok = m_trade.SellLimit(volume, price, symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
      if(!ok)
      {
         if(m_log != NULL) m_log.Error(StringFormat("SellLimit failed for %s: retcode=%d (%s)",
                              symbol, m_trade.ResultRetcode(), m_trade.ResultRetcodeDescription()));
         return false;
      }
      ticketOut = m_trade.ResultOrder();
      if(m_log != NULL) m_log.Info(StringFormat("SellLimit placed: %s vol=%.2f price=%.5f sl=%.5f tp=%.5f ticket=%I64u",
                           symbol, volume, price, sl, tp, ticketOut));
      return true;
   }

   bool CancelOrder(ulong ticket)
   {
      if(!OrderSelect(ticket)) return true; // already gone
      bool ok = m_trade.OrderDelete(ticket);
      if(!ok && m_log != NULL)
         m_log.Error(StringFormat("OrderDelete failed for ticket %I64u: retcode=%d", ticket, m_trade.ResultRetcode()));
      return ok;
   }

   bool ModifyPositionSlTp(ulong ticket, double sl, double tp)
   {
      bool ok = m_trade.PositionModify(ticket, sl, tp);
      if(!ok && m_log != NULL)
         m_log.Error(StringFormat("PositionModify failed for ticket %I64u: retcode=%d", ticket, m_trade.ResultRetcode()));
      return ok;
   }

   bool ClosePositionPartial(ulong ticket, double volume)
   {
      bool ok = m_trade.PositionClosePartial(ticket, volume);
      if(!ok && m_log != NULL)
         m_log.Error(StringFormat("Partial close failed for ticket %I64u: retcode=%d", ticket, m_trade.ResultRetcode()));
      return ok;
   }
};

#endif // __LSEA_EXECUTIONENGINE_MQH__
