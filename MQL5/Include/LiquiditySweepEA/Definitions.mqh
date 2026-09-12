//+------------------------------------------------------------------+
//| Definitions.mqh                                                   |
//| Shared enums, structs and constants for LiquiditySweepEA          |
//+------------------------------------------------------------------+
#ifndef __LSEA_DEFINITIONS_MQH__
#define __LSEA_DEFINITIONS_MQH__

//--- Trading mode -----------------------------------------------------
enum ENUM_TRADING_MODE
{
   MODE_DEMO,     // Demo / paper trading (default, recommended)
   MODE_LIVE,     // Live trading - requires explicit confirmations
   MODE_RESEARCH, // Signals + journal only, never sends orders
   MODE_DISABLED  // EA fully inactive
};

//--- Strategy state machine -------------------------------------------
enum ENUM_EA_STATE
{
   STATE_IDLE,
   STATE_FRACTAL_FOUND,
   STATE_SWEEP_DETECTED,
   STATE_M5_ARMED,
   STATE_CONFIRMATION_WAIT,
   STATE_ENGULFING_CONFIRMED,
   STATE_SETUP_VALIDATED,
   STATE_PENDING_ORDER_PLACED,
   STATE_POSITION_OPEN,
   STATE_TRADE_MANAGEMENT,
   STATE_TP_REACHED,
   STATE_SL_REACHED,
   STATE_SETUP_EXPIRED,
   STATE_RISK_LOCKED,
   STATE_ERROR_RECOVERY
};

//--- Risk model ---------------------------------------------------------
enum ENUM_RISK_MODEL
{
   RISK_FIXED_LOT,
   RISK_FIXED_USD,
   RISK_PERCENT_BALANCE,
   RISK_PERCENT_EQUITY
};

//--- Per-symbol runtime state --------------------------------------------
struct SymbolState
{
   string         symbol;
   ENUM_EA_STATE  state;

   //--- structure (H1)
   double         fractalHigh;
   datetime       fractalHighTime;
   bool           fractalHighConsumed;
   double         fractalLow;
   datetime       fractalLowTime;
   bool           fractalLowConsumed;

   //--- sweep
   bool           sweepActive;
   bool           sweepIsBuySide;   // true = sweep of a low (bullish setup)
   double         sweepLevel;
   datetime       sweepTime;
   datetime       sweepStructureTime; // time of the fractal that was swept (dup-prevention key)

   //--- M5 engulfing setup
   double         engulfingOpen, engulfingClose, engulfingHigh, engulfingLow;
   datetime       engulfingTime;

   //--- pending / open trade tracking
   ulong          pendingTicket;
   ulong          positionTicket;
   datetime       setupExpiryTime;

   //--- account protection (per symbol bookkeeping, some fields mirror account-wide guard)
   int            dailyTrades;
   int            consecutiveLosses;

   //--- score / diagnostics for dashboard
   int            lastScore;
   string         lastGrade;
   string         lastReasons;
};

//--- Trade record for the CSV journal ------------------------------------
struct TradeJournalRecord
{
   datetime timestamp;
   string   symbol;
   string   direction;
   string   session;
   int      setupScore;
   double   entry, sl, tp;
   double   riskUsd;
   double   lot;
   string   reason;
};

//--- misc constants -------------------------------------------------------
#define LSEA_MAGIC_DEFAULT 260901
#define LSEA_MAX_SYMBOLS   16

#endif // __LSEA_DEFINITIONS_MQH__
