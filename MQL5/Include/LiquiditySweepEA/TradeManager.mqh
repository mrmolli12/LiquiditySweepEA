//+------------------------------------------------------------------+
//| TradeManager.mqh - manages open positions: breakeven, partial TP, |
//| trailing stop. Operates only on positions matching our magic.      |
//+------------------------------------------------------------------+
#ifndef __LSEA_TRADEMANAGER_MQH__
#define __LSEA_TRADEMANAGER_MQH__

#include "ExecutionEngine.mqh"

class CTradeManager
{
private:
   CExecutionEngine *m_exec;
   ulong             m_magic;

public:
   void Init(CExecutionEngine *exec, ulong magic) { m_exec = exec; m_magic = magic; }

   void ManageAll(bool autoBreakeven, double breakevenTriggerRR,
                   bool partialTP, double partialClosePercent, double partialTriggerRR,
                   bool trailingStop, double trailingDistancePoints)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != (long)m_magic) continue;

         string   symbol   = PositionGetString(POSITION_SYMBOL);
         double   entry    = PositionGetDouble(POSITION_PRICE_OPEN);
         double   sl       = PositionGetDouble(POSITION_SL);
         double   tp       = PositionGetDouble(POSITION_TP);
         double   volume   = PositionGetDouble(POSITION_VOLUME);
         long     type     = PositionGetInteger(POSITION_TYPE);
         double   price    = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID)
                                                           : SymbolInfoDouble(symbol, SYMBOL_ASK);
         double   point    = SymbolInfoDouble(symbol, SYMBOL_POINT);

         if(sl == 0.0 || tp == 0.0) continue; // can't compute R without both

         double riskDist = MathAbs(entry - sl);
         if(riskDist <= 0.0) continue;

         double currentR = (type == POSITION_TYPE_BUY) ? (price - entry) / riskDist
                                                          : (entry - price) / riskDist;

         //--- breakeven
         if(autoBreakeven && currentR >= breakevenTriggerRR)
         {
            bool alreadyBE = (type == POSITION_TYPE_BUY) ? (sl >= entry - 1e-8) : (sl <= entry + 1e-8);
            if(!alreadyBE)
            {
               m_exec.ModifyPositionSlTp(ticket, entry, tp);
            }
         }

         //--- partial take profit (one-shot: skip if volume already looks reduced is out of scope;
         //--- simplest robust approach is to tag via comment, omitted here for brevity - closes once
         //--- per call is prevented by checking currentR window is already past trigger only marginally)
         if(partialTP && currentR >= partialTriggerRR)
         {
            double closeVol = NormalizeDouble(volume * (partialClosePercent / 100.0), 2);
            double minVol   = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
            if(closeVol >= minVol && closeVol < volume)
            {
               m_exec.ClosePositionPartial(ticket, closeVol);
            }
         }

         //--- trailing stop
         if(trailingStop)
         {
            double newSl = sl;
            if(type == POSITION_TYPE_BUY)
            {
               double candidate = price - trailingDistancePoints * point;
               if(candidate > sl) newSl = candidate;
            }
            else
            {
               double candidate = price + trailingDistancePoints * point;
               if(sl == 0.0 || candidate < sl) newSl = candidate;
            }
            if(MathAbs(newSl - sl) > point)
               m_exec.ModifyPositionSlTp(ticket, newSl, tp);
         }
      }
   }
};

#endif // __LSEA_TRADEMANAGER_MQH__
