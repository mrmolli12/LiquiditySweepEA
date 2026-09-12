//+------------------------------------------------------------------+
//| SessionFilter.mqh - trading-session and spread gating              |
//+------------------------------------------------------------------+
#ifndef __LSEA_SESSIONFILTER_MQH__
#define __LSEA_SESSIONFILTER_MQH__

class CSessionFilter
{
public:
   // start/end given as "HH:MM" in broker (server) time.
   bool InSession(string startHHMM, string endHHMM)
   {
      MqlDateTime now;
      TimeToStruct(TimeCurrent(), now);
      int nowMinutes = now.hour * 60 + now.min;

      int sh, sm, eh, em;
      if(!ParseHHMM(startHHMM, sh, sm)) return true;  // fail-open on bad input, but log elsewhere
      if(!ParseHHMM(endHHMM, eh, em))   return true;

      int startMinutes = sh * 60 + sm;
      int endMinutes   = eh * 60 + em;

      if(startMinutes <= endMinutes)
         return (nowMinutes >= startMinutes && nowMinutes <= endMinutes);
      else // session wraps midnight
         return (nowMinutes >= startMinutes || nowMinutes <= endMinutes);
   }

   string CurrentSessionLabel(string londonStart, string londonEnd, string nyStart, string nyEnd, string asianStart, string asianEnd)
   {
      string label = "";
      if(InSession(asianStart, asianEnd))  label += "ASIAN ";
      if(InSession(londonStart, londonEnd)) label += "LONDON ";
      if(InSession(nyStart, nyEnd))         label += "NEWYORK ";
      if(label == "") label = "OFF-SESSION";
      return label;
   }

private:
   bool ParseHHMM(string s, int &h, int &m)
   {
      string parts[];
      int n = StringSplit(s, ':', parts);
      if(n != 2) return false;
      h = (int)StringToInteger(parts[0]);
      m = (int)StringToInteger(parts[1]);
      return true;
   }
};

class CSpreadFilter
{
public:
   double CurrentSpreadPoints(const string symbol)
   {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double ask   = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double bid   = SymbolInfoDouble(symbol, SYMBOL_BID);
      if(point <= 0.0) return 0.0;
      return (ask - bid) / point;
   }

   bool IsSpreadAcceptable(const string symbol, double maxSpreadPoints)
   {
      if(maxSpreadPoints <= 0) return true; // filter disabled
      return CurrentSpreadPoints(symbol) <= maxSpreadPoints;
   }
};

#endif // __LSEA_SESSIONFILTER_MQH__
