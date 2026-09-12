//+------------------------------------------------------------------+
//| Logger.mqh - simple leveled logger, never swallows errors         |
//+------------------------------------------------------------------+
#ifndef __LSEA_LOGGER_MQH__
#define __LSEA_LOGGER_MQH__

enum ENUM_LOG_LEVEL { LOG_DEBUG=0, LOG_INFO=1, LOG_WARN=2, LOG_ERROR=3 };

class CLogger
{
private:
   ENUM_LOG_LEVEL m_minLevel;
   string         m_prefix;

   string LevelTag(ENUM_LOG_LEVEL lvl)
   {
      switch(lvl)
      {
         case LOG_DEBUG: return "DEBUG";
         case LOG_INFO:  return "INFO";
         case LOG_WARN:  return "WARN";
         case LOG_ERROR: return "ERROR";
      }
      return "?";
   }

public:
   CLogger(void) { m_minLevel = LOG_INFO; m_prefix = "[LSEA]"; }

   void Init(ENUM_LOG_LEVEL minLevel, string prefix)
   {
      m_minLevel = minLevel;
      m_prefix   = prefix;
   }

   void Write(ENUM_LOG_LEVEL lvl, string msg)
   {
      if(lvl < m_minLevel) return;
      PrintFormat("%s [%s] %s", m_prefix, LevelTag(lvl), msg);
   }

   void Debug(string msg) { Write(LOG_DEBUG, msg); }
   void Info(string msg)  { Write(LOG_INFO,  msg); }
   void Warn(string msg)  { Write(LOG_WARN,  msg); }
   void Error(string msg) { Write(LOG_ERROR, msg); }

   // Checks the last trade/broker error and logs it - never call this and then
   // silently continue as if nothing happened; caller decides how to react.
   void LogLastError(string context)
   {
      int code = GetLastError();
      if(code != 0)
      {
         PrintFormat("%s [ERROR] %s failed - error %d (%s)", m_prefix, context, code, ErrorDescription(code));
         ResetLastError();
      }
   }

   string ErrorDescription(int code)
   {
      // Minimal mapping of the most common trade server return codes.
      switch(code)
      {
         case 10004: return "Requote";
         case 10006: return "Request rejected";
         case 10007: return "Request canceled by trader";
         case 10008: return "Order placed";
         case 10009: return "Request completed";
         case 10013: return "Invalid request";
         case 10014: return "Invalid volume";
         case 10015: return "Invalid price";
         case 10016: return "Invalid stops";
         case 10018: return "Market closed";
         case 10019: return "Not enough money";
         case 10021: return "No quotes to process request";
         case 10027: return "AutoTrading disabled by client terminal";
         case 10031: return "No connection with the trade server";
      }
      return "See MQL5 documentation for code " + IntegerToString(code);
   }
};

#endif // __LSEA_LOGGER_MQH__
