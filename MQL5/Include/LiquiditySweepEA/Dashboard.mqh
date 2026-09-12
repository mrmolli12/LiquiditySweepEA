//+------------------------------------------------------------------+
//| Dashboard.mqh - on-chart command center                            |
//+------------------------------------------------------------------+
#ifndef __LSEA_DASHBOARD_MQH__
#define __LSEA_DASHBOARD_MQH__

#include "Definitions.mqh"

class CDashboard
{
private:
   string m_prefix;
   int    m_x, m_y, m_lineHeight;
   int    m_panelOuterPad, m_panelInnerPad;
   int    m_numLines;

   // All dashboard text is normal-sized, black, non-bold - only the background
   // panel layers (outer green / inner red) carry color.
   void Label(string name, string text, int line, int fontSize = 10)
   {
      string obj = m_prefix + name;
      if(ObjectFind(0, obj) < 0)
      {
         ObjectCreate(0, obj, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, obj, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, m_x + m_panelInnerPad);
         ObjectSetInteger(0, obj, OBJPROP_FONTSIZE, fontSize);
         ObjectSetString(0, obj, OBJPROP_FONT, "Arial"); // normal weight, not bold
         ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, obj, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, obj, OBJPROP_BACK, false); // text always drawn above the panel
      }
      ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, m_y + m_panelInnerPad + line * m_lineHeight);
      ObjectSetString(0, obj, OBJPROP_TEXT, text);
      ObjectSetInteger(0, obj, OBJPROP_COLOR, clrBlack); // font colour: black, as requested
   }

   void RectLayer(string name, int x, int y, int w, int h, color bg, color border)
   {
      string obj = m_prefix + name;
      if(ObjectFind(0, obj) < 0)
      {
         ObjectCreate(0, obj, OBJ_RECTANGLE_LABEL, 0, 0, 0);
         ObjectSetInteger(0, obj, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, obj, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, obj, OBJPROP_BACK, true);   // stays behind the text labels
         ObjectSetInteger(0, obj, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, obj, OBJPROP_WIDTH, 1);
      }
      ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, obj, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, obj, OBJPROP_YSIZE, h);
      ObjectSetInteger(0, obj, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, obj, OBJPROP_COLOR, border);
   }

public:
   CDashboard(void)
   {
      m_prefix = "LSEA_DASH_";
      m_x = 10; m_y = 20; m_lineHeight = 16;
      m_panelOuterPad = 10; m_panelInnerPad = 14;
      m_numLines = 9; // must match the number of Label() calls in Render()
   }

   void Render(ENUM_TRADING_MODE mode, const SymbolState &st, double bid, double ask,
               string sessionLabel, double spreadPoints, string regime,
               double riskUsd, double lot, double dailyLossUsd, double drawdownPct, double marginLevel,
               int openPositions, int pendingOrders)
   {
      //--- layered panel background: outer = green, inner = red -----------
      int innerW = 380, innerH = m_numLines * m_lineHeight + m_panelInnerPad;
      int outerX = m_x - m_panelOuterPad;
      int outerY = m_y - m_panelOuterPad;
      int outerW = innerW + 2 * m_panelOuterPad;
      int outerH = innerH + 2 * m_panelOuterPad;

      RectLayer("panel_outer", outerX, outerY, outerW, outerH, clrGreen, clrDarkGreen);
      RectLayer("panel_inner", m_x, m_y, innerW, innerH, clrRed, clrDarkRed);

      int line = 0;
      string modeText = (mode == MODE_LIVE) ? "*** LIVE TRADING ENABLED ***" :
                         (mode == MODE_DEMO) ? "DEMO MODE" :
                         (mode == MODE_RESEARCH) ? "RESEARCH MODE (no orders sent)" : "DISABLED";

      Label("mode", "MODE: " + modeText, line++);
      Label("market", StringFormat("MARKET  %s  Bid:%.5f Ask:%.5f Spread:%.1fp", st.symbol, bid, ask, spreadPoints), line++);
      Label("session", "SESSION  " + sessionLabel + "   REGIME: " + regime, line++);
      Label("state", "STATE   " + EnumToString(st.state), line++);
      Label("struct", StringFormat("STRUCT  FractalHigh:%.5f FractalLow:%.5f", st.fractalHigh, st.fractalLow), line++);
      Label("setup", StringFormat("SETUP   Score:%d Grade:%s", st.lastScore, st.lastGrade), line++);
      Label("reasons", "REASONS " + st.lastReasons, line++);
      Label("risk", StringFormat("RISK    RiskUSD:%.2f Lot:%.2f", riskUsd, lot), line++);
      Label("guard", StringFormat("GUARD   DailyLoss:%.2f DD:%.2f%% MarginLvl:%.0f%%  Open:%d Pending:%d",
                                    dailyLossUsd, drawdownPct, marginLevel, openPositions, pendingOrders), line++);

      ChartRedraw(0);
   }

   void Clear()
   {
      ObjectsDeleteAll(0, m_prefix);
   }
};

#endif // __LSEA_DASHBOARD_MQH__
