//+------------------------------------------------------------------+
//|                                              LiquiditySweepEA.mq5 |
//|  H1 fractal liquidity-sweep + M5 engulfing confirmation EA        |
//|                                                                    |
//|  IMPORTANT: This EA does not guarantee profitability. Backtesting |
//|  results do not guarantee future performance. Always validate on |
//|  a DEMO account before considering LIVE trading.                  |
//+------------------------------------------------------------------+
#property copyright "LiquiditySweepEA"
#property version   "1.00"
#property strict

#include <LiquiditySweepEA/Definitions.mqh>
#include <LiquiditySweepEA/Logger.mqh>
#include <LiquiditySweepEA/FractalEngine.mqh>
#include <LiquiditySweepEA/LiquiditySweep.mqh>
#include <LiquiditySweepEA/EngulfingEngine.mqh>
#include <LiquiditySweepEA/RiskEngine.mqh>
#include <LiquiditySweepEA/AccountGuard.mqh>
#include <LiquiditySweepEA/SessionFilter.mqh>
#include <LiquiditySweepEA/NewsFilter.mqh>
#include <LiquiditySweepEA/ExecutionEngine.mqh>
#include <LiquiditySweepEA/TradeManager.mqh>
#include <LiquiditySweepEA/Journal.mqh>
#include <LiquiditySweepEA/ScoreEngine.mqh>
#include <LiquiditySweepEA/Dashboard.mqh>

//======================== INPUTS =====================================

input group "=== TRADING MODE (SAFETY) ==="
input ENUM_TRADING_MODE TradingMode              = MODE_DEMO;  // Default: DEMO. Never starts LIVE without both flags below.
input bool   AllowLiveTrading                    = false;      // Must be true AND account must be a real account
input bool   LiveTradingConfirmation             = false;      // Second explicit confirmation, required for LIVE
input bool   EmergencyKillSwitch                 = false;      // true = force-disable all new trades immediately

input group "=== SYMBOLS ==="
input string AdditionalSymbols                   = "";         // Comma-separated extra symbols to scan, e.g. "GBPUSD,USDJPY". Chart symbol is always included.

input group "=== STRATEGY: STRUCTURE & SWEEP ==="
input int    FractalPeriod                       = 2;          // Bars each side for a confirmed fractal
input double SweepMinimumPenetrationPoints       = 20;         // Minimum wick penetration beyond the fractal, in points
input bool   SweepCloseBackRequirement           = true;       // Require the sweep candle to close back inside the level
input int    SweepMaxAgeH1Bars                   = 48;         // Fractal expires (no sweep) after this many H1 bars

input group "=== STRATEGY: M5 ENGULFING ==="
input double EngulfingMinimumBodyPoints          = 30;
input double EngulfingMinimumRangePoints         = 40;
input double EngulfingBodyPercentage             = 0.55;       // body/range, 0..1
input int    EngulfingMaxBarsToWait              = 24;         // M5 bars to wait for confirmation after a sweep

input group "=== ADVANCED FILTERS (NOT FULLY IMPLEMENTED - see README) ==="
input bool   UseBOSFilter                        = false;      // stub: logs a warning and passes through if enabled
input bool   UseMSSFilter                        = false;      // stub
input bool   UseFVGFilter                        = false;      // stub
input bool   UsePremiumDiscountFilter            = false;      // stub

input group "=== SETUP QUALITY ==="
input int    MinimumSetupScore                   = 5;          // out of the max possible score for enabled filters

input group "=== RISK ==="
input ENUM_RISK_MODEL RiskModel                  = RISK_PERCENT_BALANCE;
input double FixedLotSize                        = 0.01;
input double RiskAmountUSD                       = 25.0;
input double RiskPercentage                      = 0.5;
input double RiskRewardRatio                     = 3.0;
input double StopLossBufferPoints                = 15;         // extra buffer beyond the engulfing candle's wick

input group "=== SESSIONS (broker/server time, HH:MM) ==="
input bool   UseSessionFilter                    = true;
input string LondonSessionStart                  = "08:00";
input string LondonSessionEnd                    = "16:30";
input string NewYorkSessionStart                 = "13:00";
input string NewYorkSessionEnd                   = "21:00";
input string AsianSessionStart                   = "00:00";
input string AsianSessionEnd                     = "08:00";

input group "=== SPREAD ==="
input double MaximumSpreadAllowedPoints          = 25;         // 0 = disabled

input group "=== ACCOUNT PROTECTION ==="
input double MaximumDailyLossUSD                 = 0;          // 0 = disabled
input double MaximumDailyLossPercent             = 3.0;        // 0 = disabled
input double MaximumAccountDrawdownPercent       = 10.0;       // 0 = disabled
input int    MaximumDailyTrades                  = 6;          // 0 = disabled
input int    MaximumOpenPositions                = 3;          // 0 = disabled
input int    MaximumConsecutiveLosses            = 4;          // 0 = disabled

input group "=== TRADE DIRECTIONS ==="
input bool   EnableBuyTrades                     = true;
input bool   EnableSellTrades                    = true;

input group "=== NEWS (best-effort, needs broker calendar support) ==="
input bool   UseNewsFilter                       = true;
input int    NewsMinutesBefore                   = 30;
input int    NewsMinutesAfter                    = 30;
input bool   BlockHighImpact                     = true;
input bool   BlockMediumImpact                   = false;

input group "=== EXECUTION ==="
input ulong  MagicNumber                         = LSEA_MAGIC_DEFAULT;
input ulong  SlippagePoints                      = 20;
input string TradeComment                        = "LSEA";

input group "=== TRADE MANAGEMENT ==="
input bool   AutoBreakeven                       = true;
input double BreakevenTriggerRR                  = 1.0;
input bool   PartialTakeProfit                   = false;
input double PartialClosePercentage              = 50.0;
input double PartialTPTriggerRR                  = 1.5;
input bool   TrailingStop                        = false;
input double TrailingStopDistancePoints          = 150;

input group "=== DASHBOARD & ALERTS ==="
input bool   EnableDashboard                     = true;
input bool   EnableNotifications                 = false; // MT5 push notifications
input bool   EnableEmailAlerts                   = false; // requires Email configured in Tools->Options

//======================== GLOBALS =====================================

CLogger          g_log;
CFractalEngine   g_fractal;
CLiquiditySweep  g_sweep;
CEngulfingEngine g_engulf;
CRiskEngine      g_risk;
CAccountGuard    g_guard;
CSessionFilter   g_session;
CSpreadFilter    g_spread;
CNewsFilter      g_news;
CExecutionEngine g_exec;
CTradeManager    g_tradeMgr;
CJournal         g_journal;
CScoreEngine     g_score;
CDashboard       g_dash;

ENUM_TRADING_MODE g_effectiveMode; // may be forced to DISABLED if LIVE safety checks fail

string      g_symbols[LSEA_MAX_SYMBOLS];
SymbolState g_state[LSEA_MAX_SYMBOLS];
int         g_symbolCount = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   g_log.Init(LOG_INFO, "[LSEA]");

   //--- LIVE safety gate. Never silently allow live trading. ---------
   g_effectiveMode = TradingMode;
   if(TradingMode == MODE_LIVE)
   {
      bool isRealAccount = (AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_REAL);
      if(!AllowLiveTrading || !LiveTradingConfirmation || !isRealAccount)
      {
         g_effectiveMode = MODE_DISABLED;
         g_log.Error("LIVE mode requested but safety conditions are not met "
                     "(AllowLiveTrading, LiveTradingConfirmation, and a REAL account are all required). "
                     "EA forced to DISABLED. Fix inputs and reload if LIVE trading is really intended.");
         Alert("LiquiditySweepEA: LIVE trading blocked - safety confirmations not satisfied. EA is DISABLED.");
      }
      else
      {
         g_log.Warn("*** LIVE TRADING ENABLED *** on a REAL account. Verify all inputs before the first trade.");
      }
   }

   if(EmergencyKillSwitch)
      g_log.Warn("EmergencyKillSwitch is ON at startup - no new trades will be opened until it is turned off.");

   if(UseBOSFilter || UseMSSFilter || UseFVGFilter || UsePremiumDiscountFilter)
      g_log.Warn("One or more advanced structure filters (BOS/MSS/FVG/Premium-Discount) is enabled "
                 "but not implemented in this build - it will be scored as neutral/pass. See README.");

   //--- build symbol list ---------------------------------------------
   g_symbolCount = 0;
   AddSymbol(_Symbol);
   if(StringLen(AdditionalSymbols) > 0)
   {
      string parts[];
      int n = StringSplit(AdditionalSymbols, ',', parts);
      for(int i = 0; i < n; i++)
      {
         string s = TrimString(parts[i]);
         if(StringLen(s) > 0) AddSymbol(s);
      }
   }
   if(g_symbolCount == 0)
   {
      g_log.Error("No valid symbols to trade.");
      return INIT_FAILED;
   }

   for(int i = 0; i < g_symbolCount; i++)
   {
      if(!SymbolSelect(g_symbols[i], true))
         g_log.Warn("Could not select symbol in Market Watch: " + g_symbols[i]);
   }

   //--- configure engines ----------------------------------------------
   g_fractal.SetPeriod(FractalPeriod);
   g_sweep.Configure(SweepMinimumPenetrationPoints, SweepCloseBackRequirement, SweepMaxAgeH1Bars);
   g_engulf.Configure(EngulfingMinimumBodyPoints, EngulfingMinimumRangePoints, EngulfingBodyPercentage, EngulfingMaxBarsToWait);
   g_risk.SetLogger(GetPointer(g_log));
   g_news.SetLogger(GetPointer(g_log));
   g_exec.Init(MagicNumber, SlippagePoints, GetPointer(g_log));
   g_tradeMgr.Init(GetPointer(g_exec), MagicNumber);
   g_journal.Init("LiquiditySweepEA_Journal.csv");

   EventSetTimer(2);
   g_log.Info(StringFormat("Initialized. Mode=%s Symbols=%d Magic=%I64u", EnumToString(g_effectiveMode), g_symbolCount, MagicNumber));
   return INIT_SUCCEEDED;
}

void AddSymbol(string s)
{
   if(g_symbolCount >= LSEA_MAX_SYMBOLS) return;
   for(int i = 0; i < g_symbolCount; i++) if(g_symbols[i] == s) return; // no duplicates
   g_symbols[g_symbolCount] = s;
   g_state[g_symbolCount].symbol = s;
   g_state[g_symbolCount].state  = STATE_IDLE;
   g_symbolCount++;
}

string TrimString(string s)
{
   StringTrimLeft(s);
   StringTrimRight(s);
   return s;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   g_dash.Clear();
   g_log.Info("Deinitialized, reason=" + IntegerToString(reason));
}

//+------------------------------------------------------------------+
void OnTimer()
{
   g_guard.OnTick();
   if(EnableDashboard) RenderDashboard();
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(g_effectiveMode == MODE_DISABLED) return;

   g_guard.OnTick();

   for(int i = 0; i < g_symbolCount; i++)
      ProcessSymbol(i);

   //--- manage all existing positions (breakeven/partial/trailing) ---
   g_tradeMgr.ManageAll(AutoBreakeven, BreakevenTriggerRR, PartialTakeProfit, PartialClosePercentage,
                         PartialTPTriggerRR, TrailingStop, TrailingStopDistancePoints);
}

//+------------------------------------------------------------------+
//| Core per-symbol state machine                                     |
//+------------------------------------------------------------------+
void ProcessSymbol(int idx)
{
   SymbolState state = g_state[idx];
   string sym = state.symbol;

   switch(state.state)
   {
      case STATE_IDLE:
      case STATE_SETUP_EXPIRED:
      {
         state.state = STATE_IDLE;

         double fl, fh; datetime flt, fht;
         if(g_fractal.FindLatestConfirmedLow(sym, fl, flt) && flt != state.fractalLowTime)
         {
            state.fractalLow = fl; state.fractalLowTime = flt; state.fractalLowConsumed = false;
         }
         if(g_fractal.FindLatestConfirmedHigh(sym, fh, fht) && fht != state.fractalHighTime)
         {
            state.fractalHigh = fh; state.fractalHighTime = fht; state.fractalHighConsumed = false;
         }

         datetime sweepT;
         if(EnableBuyTrades && !state.fractalLowConsumed && state.fractalLowTime > 0 &&
            !g_sweep.IsFractalExpired(sym, state.fractalLowTime) &&
            g_sweep.CheckSweepBelow(sym, state.fractalLow, sweepT))
         {
            state.fractalLowConsumed = true;
            state.sweepIsBuySide = true;
            state.sweepLevel = state.fractalLow;
            state.sweepTime = sweepT;
            state.state = STATE_SWEEP_DETECTED;
            g_log.Info(StringFormat("%s: buy-side liquidity sweep detected below %.5f", sym, state.fractalLow));
         }
         else if(EnableSellTrades && !state.fractalHighConsumed && state.fractalHighTime > 0 &&
                 !g_sweep.IsFractalExpired(sym, state.fractalHighTime) &&
                 g_sweep.CheckSweepAbove(sym, state.fractalHigh, sweepT))
         {
            state.fractalHighConsumed = true;
            state.sweepIsBuySide = false;
            state.sweepLevel = state.fractalHigh;
            state.sweepTime = sweepT;
            state.state = STATE_SWEEP_DETECTED;
            g_log.Info(StringFormat("%s: sell-side liquidity sweep detected above %.5f", sym, state.fractalHigh));
         }
         break;
      }

      case STATE_SWEEP_DETECTED:
         state.state = STATE_M5_ARMED;
         break;

      case STATE_M5_ARMED:
      case STATE_CONFIRMATION_WAIT:
      {
         state.state = STATE_CONFIRMATION_WAIT;
         if(g_engulf.TimedOut(sym, state.sweepTime))
         {
            g_log.Info(sym + ": setup expired waiting for engulfing confirmation.");
            state.state = STATE_SETUP_EXPIRED;
            break;
         }

         double o, c, h, l; datetime t;
         bool found = state.sweepIsBuySide ? g_engulf.CheckBullish(sym, o, c, h, l, t)
                                             : g_engulf.CheckBearish(sym, o, c, h, l, t);
         if(found)
         {
            state.engulfingOpen = o; state.engulfingClose = c;
            state.engulfingHigh = h; state.engulfingLow  = l;
            state.engulfingTime = t;
            state.state = STATE_ENGULFING_CONFIRMED;
         }
         break;
      }

      case STATE_ENGULFING_CONFIRMED:
         EvaluateAndExecuteSetup(idx, state);
         break;

      case STATE_PENDING_ORDER_PLACED:
         CheckPendingOrderStatus(idx, state);
         break;

      case STATE_POSITION_OPEN:
      case STATE_TRADE_MANAGEMENT:
         CheckPositionStatus(idx, state);
         break;

      case STATE_RISK_LOCKED:
      {
         string reason;
         if(g_guard.IsTradingAllowed(EmergencyKillSwitch, MaximumDailyLossUSD, MaximumDailyLossPercent,
                                       MaximumAccountDrawdownPercent, MaximumDailyTrades, MaximumConsecutiveLosses,
                                       MaximumOpenPositions, CountOpenPositions(), reason))
         {
            state.state = STATE_IDLE;
            g_log.Info(sym + ": risk lock cleared, resuming.");
         }
         break;
      }

      case STATE_ERROR_RECOVERY:
         g_log.Warn(sym + ": recovering from error state, resetting to IDLE.");
         state.state = STATE_IDLE;
         break;

      default:
         state.state = STATE_IDLE;
         break;
   }

   g_state[idx] = state;
}

//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int n = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == (long)MagicNumber) n++;
   }
   return n;
}

int CountPendingOrders()
{
   int n = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderSelect(ticket) && OrderGetInteger(ORDER_MAGIC) == (long)MagicNumber) n++;
   }
   return n;
}

//+------------------------------------------------------------------+
//| Score, filter, size and (if everything passes) place the order.   |
//+------------------------------------------------------------------+
void EvaluateAndExecuteSetup(int idx, SymbolState &state)
{
   string sym = state.symbol;

   //--- account-wide guard first: never trade if locked ---------------
   string guardReason;
   bool allowed = g_guard.IsTradingAllowed(EmergencyKillSwitch, MaximumDailyLossUSD, MaximumDailyLossPercent,
                                             MaximumAccountDrawdownPercent, MaximumDailyTrades, MaximumConsecutiveLosses,
                                             MaximumOpenPositions, CountOpenPositions(), guardReason);
   if(!allowed)
   {
      g_log.Warn(sym + ": trade blocked by account guard - " + guardReason);
      state.state = STATE_RISK_LOCKED;
      return;
   }

   if(g_effectiveMode == MODE_DISABLED)
   {
      state.state = STATE_SETUP_EXPIRED;
      return;
   }

   //--- filters ----------------------------------------------------------
   bool sessionOk = true;
   string sessionLabel = g_session.CurrentSessionLabel(LondonSessionStart, LondonSessionEnd,
                                                         NewYorkSessionStart, NewYorkSessionEnd,
                                                         AsianSessionStart, AsianSessionEnd);
   if(UseSessionFilter)
      sessionOk = g_session.InSession(LondonSessionStart, LondonSessionEnd) ||
                  g_session.InSession(NewYorkSessionStart, NewYorkSessionEnd);

   bool spreadOk = g_spread.IsSpreadAcceptable(sym, MaximumSpreadAllowedPoints);
   bool newsOk   = UseNewsFilter ? g_news.IsSafeToTrade(sym, NewsMinutesBefore, NewsMinutesAfter, BlockHighImpact, BlockMediumImpact) : true;

   //--- setup-quality score (advanced structure filters are stubbed pass-through) ---
   int maxScore; string reasons;
   int rawScore = g_score.Evaluate(true, true,
                                    true, UseBOSFilter,
                                    true, UseFVGFilter,
                                    true,
                                    true, UsePremiumDiscountFilter,
                                    sessionOk, spreadOk, true, newsOk,
                                    maxScore, reasons);

   state.lastScore = rawScore;
   state.lastGrade = g_score.Grade(rawScore, maxScore);
   state.lastReasons = reasons;

   if(!sessionOk)      { g_log.Info(sym + ": rejected - outside allowed session."); state.state = STATE_SETUP_EXPIRED; return; }
   if(!spreadOk)        { g_log.Info(sym + ": rejected - spread too wide."); state.state = STATE_SETUP_EXPIRED; return; }
   if(!newsOk)          { g_log.Info(sym + ": rejected - inside a news blackout window."); state.state = STATE_SETUP_EXPIRED; return; }
   if(rawScore < MinimumSetupScore)
   {
      g_log.Info(StringFormat("%s: rejected - score %d/%d below MinimumSetupScore %d", sym, rawScore, maxScore, MinimumSetupScore));
      state.state = STATE_SETUP_EXPIRED;
      return;
   }

   //--- build entry/SL/TP -------------------------------------------------
   double point  = SymbolInfoDouble(sym, SYMBOL_POINT);
   double digits = (double)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double entry, sl, tp;
   ENUM_ORDER_TYPE orderType;

   if(state.sweepIsBuySide)
   {
      entry = (state.engulfingOpen + state.engulfingClose) / 2.0;
      sl    = state.engulfingLow - StopLossBufferPoints * point;
      double risk = entry - sl;
      tp    = entry + risk * RiskRewardRatio;
      orderType = ORDER_TYPE_BUY_LIMIT;
   }
   else
   {
      entry = (state.engulfingOpen + state.engulfingClose) / 2.0;
      sl    = state.engulfingHigh + StopLossBufferPoints * point;
      double risk = sl - entry;
      tp    = entry - risk * RiskRewardRatio;
      orderType = ORDER_TYPE_SELL_LIMIT;
   }

   entry = NormalizeDouble(entry, (int)digits);
   sl    = NormalizeDouble(sl, (int)digits);
   tp    = NormalizeDouble(tp, (int)digits);

   double slDistance = MathAbs(entry - sl);
   double lot = g_risk.CalculateLotSize(sym, RiskModel, FixedLotSize, RiskAmountUSD, RiskPercentage, slDistance);
   if(lot <= 0.0)
   {
      g_log.Warn(sym + ": rejected - risk engine could not produce a valid lot size.");
      state.state = STATE_SETUP_EXPIRED;
      return;
   }

   string rejectReason;
   if(!g_risk.ValidateTrade(sym, orderType, entry, sl, tp, lot, rejectReason))
   {
      g_log.Warn(sym + ": trade validation failed - " + rejectReason + ". DO NOT TRADE.");
      state.state = STATE_SETUP_EXPIRED;
      return;
   }

   //--- send the order ------------------------------------------------
   ulong ticket = 0;
   bool sent;
   if(orderType == ORDER_TYPE_BUY_LIMIT)
      sent = g_exec.PlaceBuyLimit(sym, lot, entry, sl, tp, TradeComment, ticket);
   else
      sent = g_exec.PlaceSellLimit(sym, lot, entry, sl, tp, TradeComment, ticket);

   if(!sent)
   {
      state.state = STATE_ERROR_RECOVERY;
      return;
   }

   state.pendingTicket   = ticket;
   state.setupExpiryTime = TimeCurrent() + EngulfingMaxBarsToWait * PeriodSeconds(PERIOD_M5);
   state.state           = STATE_PENDING_ORDER_PLACED;
   g_guard.RegisterTradeOpened();

   if(EnableNotifications) SendNotification(StringFormat("LSEA %s %s @ %.5f", sym, state.sweepIsBuySide ? "BUY" : "SELL", entry));
   if(EnableEmailAlerts)   SendMail("LiquiditySweepEA trade", StringFormat("%s %s entry=%.5f sl=%.5f tp=%.5f lot=%.2f", sym, state.sweepIsBuySide ? "BUY" : "SELL", entry, sl, tp, lot));

   TradeJournalRecord rec;
   rec.timestamp  = TimeCurrent();
   rec.symbol     = sym;
   rec.direction  = state.sweepIsBuySide ? "BUY" : "SELL";
   rec.session    = sessionLabel;
   rec.setupScore = rawScore;
   rec.entry = entry; rec.sl = sl; rec.tp = tp;
   rec.riskUsd = (RiskModel == RISK_FIXED_USD) ? RiskAmountUSD : slDistance * (SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_VALUE)/SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE)) * lot;
   rec.lot = lot;
   rec.reason = "Setup validated, order sent";
   g_journal.WriteRecord(rec);
}

//+------------------------------------------------------------------+
void CheckPendingOrderStatus(int idx, SymbolState &state)
{
   bool pendingExists = OrderSelect(state.pendingTicket);

   // Look for a live position that matches our magic+symbol and wasn't there before.
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != state.symbol) continue;

      // Heuristic: newly opened position while we were waiting on this ticket's fill.
      if((datetime)PositionGetInteger(POSITION_TIME) >= state.sweepTime)
      {
         state.positionTicket = ticket;
         state.state = STATE_POSITION_OPEN;
         g_log.Info(state.symbol + ": pending order filled, position open.");
         return;
      }
   }

   if(!pendingExists)
   {
      // Order is gone and no matching position appeared -> canceled/expired/rejected.
      g_log.Info(state.symbol + ": pending order no longer active (expired/canceled).");
      state.state = STATE_SETUP_EXPIRED;
      return;
   }

   if(TimeCurrent() > state.setupExpiryTime)
   {
      g_exec.CancelOrder(state.pendingTicket);
      state.state = STATE_SETUP_EXPIRED;
   }
}

//+------------------------------------------------------------------+
void CheckPositionStatus(int idx, SymbolState &state)
{
   if(!PositionSelectByTicket(state.positionTicket))
   {
      // Position closed - figure out win/loss for consecutive-loss tracking from deal history.
      bool wasLoss = false;
      if(HistorySelectByPosition(state.positionTicket))
      {
         double profit = 0.0;
         int deals = HistoryDealsTotal();
         for(int i = 0; i < deals; i++)
         {
            ulong dealTicket = HistoryDealGetTicket(i);
            profit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT) + HistoryDealGetDouble(dealTicket, DEAL_SWAP) + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
         }
         wasLoss = (profit < 0);
      }
      g_guard.RegisterTradeResult(wasLoss);
      g_log.Info(state.symbol + ": position closed, result=" + (wasLoss ? "LOSS" : "WIN/BE"));
      state.state = STATE_IDLE;
      return;
   }
   state.state = STATE_TRADE_MANAGEMENT; // actual management is done centrally by g_tradeMgr.ManageAll()
}

//+------------------------------------------------------------------+
void RenderDashboard()
{
   if(g_symbolCount == 0) return;
   SymbolState st = g_state[0];
   string sym = st.symbol;

   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   string sessionLabel = g_session.CurrentSessionLabel(LondonSessionStart, LondonSessionEnd,
                                                         NewYorkSessionStart, NewYorkSessionEnd,
                                                         AsianSessionStart, AsianSessionEnd);
   double spreadPts = g_spread.CurrentSpreadPoints(sym);

   double riskUsd = (RiskModel == RISK_FIXED_USD) ? RiskAmountUSD :
                     (RiskModel == RISK_PERCENT_BALANCE) ? AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercentage / 100.0 :
                     (RiskModel == RISK_PERCENT_EQUITY)  ? AccountInfoDouble(ACCOUNT_EQUITY)  * RiskPercentage / 100.0 : 0.0;

   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

   g_dash.Render(g_effectiveMode, st, bid, ask, sessionLabel, spreadPts, "N/A (regime engine not implemented)",
                  riskUsd, FixedLotSize, g_guard.DailyLossUsd(), g_guard.DrawdownPercent(), marginLevel,
                  CountOpenPositions(), CountPendingOrders());
}
//+------------------------------------------------------------------+
