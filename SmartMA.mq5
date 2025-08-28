//+------------------------------------------------------------------+
//|                                                     SmartMA.mq5 |
//|                     Fully Modular 55-MA Crossover Strategy      |
//|                     ©2025, Omondi Calvince (Inspired)           |
//+------------------------------------------------------------------+
#property copyright "©2025"
#property version   "1.03"
#property strict
#define USE_BARS-ACCESS;
#include <Trade/Trade.mqh>
CTrade trade;

//--- input parameters
input int    SMA_Fast1_Period = 13;
input int    SMA_Fast2_Period = 21;
input int    SMA_Slow_Period  = 55;
input int    ATR_Period       = 14;
input double ATR_Multiplier   = 2.0;
input double RiskRewardRatio  = 3.0;
input double BreakEvenRR      = 1.5;
input double LotSize          = 0.1;
input int    MaxConfirmBars   = 10;
input bool   IsCryptoPair     = false;  // true for 24/7 assets like BTCUSD

//--- indicators handle
int smaFast1Handle, smaFast2Handle, smaSlowHandle, atrHandle;

//--- global state
bool buySignalActive = false;
bool sellSignalActive = false;
bool tradedBuy = false;
bool tradedSell = false;
datetime lastBuyCrossoverTime = 0;
datetime lastSellCrossoverTime = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   smaFast1Handle = iMA(_Symbol, _Period, SMA_Fast1_Period, 0, MODE_SMA, PRICE_CLOSE);
   smaFast2Handle = iMA(_Symbol, _Period, SMA_Fast2_Period, 0, MODE_SMA, PRICE_CLOSE);
   smaSlowHandle  = iMA(_Symbol, _Period, SMA_Slow_Period, 0, MODE_SMA, PRICE_CLOSE);
   atrHandle      = iATR(_Symbol, _Period, ATR_Period);

   if(smaFast1Handle == INVALID_HANDLE || smaFast2Handle == INVALID_HANDLE || smaSlowHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
      return INIT_FAILED;

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(Bars(_Symbol, _Period) < SMA_Slow_Period + 10) return;

   if(!IsTradingTime()) return;

   if(PositionSelect(_Symbol))
   {
      CheckForceExit();
      CheckTimeToForceClose();
   }

   CheckSignals();
   ManageOpenTrade();
}

//+------------------------------------------------------------------+
void CheckSignals()
{
   double sma13, sma21, sma55;
   if(!GetMAValues(1, sma13, sma21, sma55)) return;

   if(sma55 < sma13 && sma55 < sma21 && Time[1] != lastBuyCrossoverTime)
   {
      buySignalActive = true;
      lastBuyCrossoverTime = Time[1];
      tradedBuy = false;
   }

   if(sma55 > sma13 && sma55 > sma21 && Time[1] != lastSellCrossoverTime)
   {
      sellSignalActive = true;
      lastSellCrossoverTime = Time[1];
      tradedSell = false;
   }

   if(buySignalActive && !PositionSelect(_Symbol) && !tradedBuy) TryBuyEntry();
   if(sellSignalActive && !PositionSelect(_Symbol) && !tradedSell) TrySellEntry();
}

//+------------------------------------------------------------------+
void TryBuyEntry()
{
   if(Time[0] - lastBuyCrossoverTime > MaxConfirmBars * PeriodSeconds())
   {
      buySignalActive = false;
      return;
   }

   double sma13, sma21, sma55;
   if(!GetMAValues(0, sma13, sma21, sma55)) return;

   if(Open[0] < sma55 && Close[0] < sma55) return;

   if(IsBullishCandle(0) && !IsDoji(0) && Close[0] > sma13)
   {
      double atr;
      if(!GetATR(atr)) return;

      double sl = Bid - (atr * ATR_Multiplier);
      double tp = Bid + (atr * ATR_Multiplier * RiskRewardRatio);

      if(trade.Buy(LotSize, _Symbol, Bid, sl, tp))
      {
         buySignalActive = false;
         tradedBuy = true;
      }
   }
}

//+------------------------------------------------------------------+
void TrySellEntry()
{
   if(Time[0] - lastSellCrossoverTime > MaxConfirmBars * PeriodSeconds())
   {
      sellSignalActive = false;
      return;
   }

   double sma13, sma21, sma55;
   if(!GetMAValues(0, sma13, sma21, sma55)) return;

   if(Open[0] > sma55 && Close[0] > sma55) return;

   if(IsBearishCandle(0) && !IsDoji(0) && Close[0] < sma13)
   {
      double atr;
      if(!GetATR(atr)) return;

      double sl = Ask + (atr * ATR_Multiplier);
      double tp = Ask - (atr * ATR_Multiplier * RiskRewardRatio);

      if(trade.Sell(LotSize, _Symbol, Ask, sl, tp))
      {
         sellSignalActive = false;
         tradedSell = true;
      }
   }
}

//+------------------------------------------------------------------+
void ManageOpenTrade()
{
   if(!PositionSelect(_Symbol)) return;

   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl     = PositionGetDouble(POSITION_SL);
   double tp     = PositionGetDouble(POSITION_TP);

   double atr;
   if(!GetATR(atr)) return;
   double risk = MathAbs(entry - sl);
   double target = risk * BreakEvenRR;

   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
   {
      if(Bid - entry >= target)
         trade.PositionModify(_Symbol, entry, tp);
   }
   else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
   {
      if(entry - Ask >= target)
         trade.PositionModify(_Symbol, entry, tp);
   }
}

//+------------------------------------------------------------------+
void CheckForceExit()
{
   double sma13, sma21, sma55;
   if(!GetMAValues(0, sma13, sma21, sma55)) return;

   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && sma55 > sma13 && sma55 > sma21)
      trade.PositionClose(_Symbol);

   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && sma55 < sma13 && sma55 < sma21)
      trade.PositionClose(_Symbol);
}

//+------------------------------------------------------------------+
void CheckTimeToForceClose()
{
   if(IsCryptoPair) return; // Crypto positions stay open

   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(), timeStruct);

   if(timeStruct.day_of_week == 5 && timeStruct.hour == 21 && timeStruct.min >= 50) // Friday 10 mins to close
   {
      if(PositionSelect(_Symbol))
         trade.PositionClose(_Symbol);
   }
}

//+------------------------------------------------------------------+
bool IsTradingTime()
{
   if(IsCryptoPair) return true;

   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(), timeStruct);

   // No trades during weekends
   if(timeStruct.day_of_week == 0 || timeStruct.day_of_week == 6) return false;

   // Avoid new trades 30 minutes before Friday close
   if(timeStruct.day_of_week == 5 && timeStruct.hour == 21 && timeStruct.min >= 30) return false;

   // Avoid trades in first 30 mins after Sunday open
   if(timeStruct.day_of_week == 0 && timeStruct.hour == 21 && timeStruct.min < 30) return false;

   return true;
}

//+------------------------------------------------------------------+
bool GetMAValues(int shift, double &ma13, double &ma21, double &ma55)
{
   double buffer1[], buffer2[], buffer3[];
   if(CopyBuffer(smaFast1Handle, 0, shift, 1, buffer1) != 1) return false;
   if(CopyBuffer(smaFast2Handle, 0, shift, 1, buffer2) != 1) return false;
   if(CopyBuffer(smaSlowHandle,  0, shift, 1, buffer3) != 1) return false;
   ma13 = buffer1[0];
   ma21 = buffer2[0];
   ma55 = buffer3[0];
   return true;
}

//+------------------------------------------------------------------+
bool GetATR(double &atrValue)
{
   double atrBuf[];
   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) != 1) return false;
   atrValue = atrBuf[0];
   return true;
}

//+------------------------------------------------------------------+
bool IsBullishCandle(int shift)
{
   return Close[shift] > Open[shift];
}

bool IsBearishCandle(int shift)
{
   return Close[shift] < Open[shift];
}

bool IsDoji(int shift)
{
   return MathAbs(Close[shift] - Open[shift]) <= (High[shift] - Low[shift]) * 0.1;
}
//+------------------------------------------------------------------+
