//+------------------------------------------------------------------+
//| NewsFilter.mqh - best-effort high/medium impact news blackout     |
//| using MT5's built-in Economic Calendar (MqlCalendar* API).        |
//| NOTE: calendar data availability depends on your broker/terminal. |
//| If the calendar API is unavailable this filter fails OPEN (does   |
//| not block trading) and logs a warning - it is not a silent no-op. |
//+------------------------------------------------------------------+
#ifndef __LSEA_NEWSFILTER_MQH__
#define __LSEA_NEWSFILTER_MQH__

#include "Logger.mqh"

class CNewsFilter
{
private:
   CLogger *m_log;
   bool     m_warned;

public:
   CNewsFilter(void) { m_log = NULL; m_warned = false; }
   void SetLogger(CLogger *log) { m_log = log; }

   // Returns true if it's currently safe to trade the given currency's pairs.
   bool IsSafeToTrade(const string symbol, int minutesBefore, int minutesAfter,
                       bool blockHighImpact, bool blockMediumImpact)
   {
      if(!blockHighImpact && !blockMediumImpact) return true;

      string base  = StringSubstr(symbol, 0, 3);
      string quote = StringSubstr(symbol, 3, 3);

      MqlCalendarValue values[];
      datetime from = TimeCurrent() - minutesBefore * 60;
      datetime to   = TimeCurrent() + minutesAfter  * 60;

      int total = CalendarValueHistory(values, from, to, NULL, NULL);
      if(total < 0)
      {
         if(!m_warned && m_log != NULL)
         {
            m_log.Warn("NewsFilter: economic calendar not available on this terminal/broker - news filter is inactive (fail-open).");
            m_warned = true;
         }
         return true;
      }

      for(int i = 0; i < total; i++)
      {
         MqlCalendarEvent evt;
         if(!CalendarEventById(values[i].event_id, evt)) continue;

         MqlCalendarCountry country;
         if(!CalendarCountryById(evt.country_id, country)) continue;

         bool currencyMatch = (country.currency == base || country.currency == quote);
         if(!currencyMatch) continue;

         bool impactBlocked = (blockHighImpact && evt.importance == CALENDAR_IMPORTANCE_HIGH) ||
                               (blockMediumImpact && evt.importance == CALENDAR_IMPORTANCE_MODERATE);

         if(impactBlocked) return false;
      }
      return true;
   }
};

#endif // __LSEA_NEWSFILTER_MQH__
