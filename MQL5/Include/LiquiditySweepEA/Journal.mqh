//+------------------------------------------------------------------+
//| Journal.mqh - appends every setup/trade to a CSV file under       |
//| MQL5/Files so results survive terminal restarts.                  |
//+------------------------------------------------------------------+
#ifndef __LSEA_JOURNAL_MQH__
#define __LSEA_JOURNAL_MQH__

#include "Definitions.mqh"

class CJournal
{
private:
   string m_filename;

   void EnsureHeader()
   {
      if(FileIsExist(m_filename)) return;
      int h = FileOpen(m_filename, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
      if(h == INVALID_HANDLE) return;
      FileWrite(h, "Timestamp","Symbol","Direction","Session","SetupScore","Entry","SL","TP","RiskUSD","Lot","Reason");
      FileClose(h);
   }

public:
   void Init(string filename)
   {
      m_filename = filename;
      EnsureHeader();
   }

   void WriteRecord(const TradeJournalRecord &rec)
   {
      EnsureHeader();
      int h = FileOpen(m_filename, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
      if(h == INVALID_HANDLE)
      {
         Print("[LSEA] [ERROR] Journal: could not open ", m_filename, " (error ", GetLastError(), ")");
         return;
      }
      FileSeek(h, 0, SEEK_END);
      FileWrite(h, TimeToString(rec.timestamp, TIME_DATE|TIME_SECONDS), rec.symbol, rec.direction, rec.session,
                rec.setupScore, DoubleToString(rec.entry,_Digits), DoubleToString(rec.sl,_Digits),
                DoubleToString(rec.tp,_Digits), DoubleToString(rec.riskUsd,2), DoubleToString(rec.lot,2), rec.reason);
      FileClose(h);
   }
};

#endif // __LSEA_JOURNAL_MQH__
