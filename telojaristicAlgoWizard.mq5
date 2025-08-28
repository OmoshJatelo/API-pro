//+------------------------------------------------------------------+
//|                                    teloristicAlgoWizard.mql5.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\Trade.mqh>//include trading functions
CTrade trade;

// a fuction to check if it is trading time
bool isTradingTime()
{
  
  datetime currentTime= TimeCurrent();           // get the curret date and time
  MqlDateTime tm;
  TimeToStruct(currentTime,tm);//contvert to sruct to access parts likehour, minute
  
  
  //check if the symbol is crypto
  string symbol= _Symbol;
  bool isCrypto= (StringFind(symbol,"BTC")!=-1 || StringFind(symbol,"ETH")!=-1||StringFind(symbol,"XRP")!=-1);
  //allow 24/7 trading for crypto pairs
  if(isCrypto){
     return true;
     }  
  //block forex trades on sunday
  if(tm.day_of_week==0){
    return false;
  }
  //avoid trades late friday when market is bout to be closed    
  if(tm.day_of_week==5)//friday
  {
    if((tm.hour >21||tm.hour==21)&& tm.min>=55)
       return false;
  }  
  //avoid forex on saturday,market closed
  if(tm.day_of_week==6)
    return false;
   //alloe trading all the other times
   return true; 
}

// Moving averages handles declaration
int ma13Handle, ma21Handle,ma55handle,ema8Handle;
int zigzagHandle;
input double RiskPercent = 1.0;
input double RRRatio = 3.0;
input double MaxDailyLoss = 5.0;
input double MaxDistancePips = 20;
input int Slippage = 5;
input double Lots = 0.01;

// a function to determine fresh moving average crossover
bool isFreshBullishCrossover()
{
   double ma13[2],ma21[2],ma55[2],ema8[2];//arrays/buffers for storing the last two values for wachma
   //fetch the last two values of each MA
   if(CopyBuffer(ma13Handle,0,0,2,ma13)<2) return false;
   if(CopyBuffer(ma21Handle,0,0,2,ma21)<2) return false;//we check to enrsure that all the two vaues are loaded
   if(CopyBuffer(ma55handle,0,0,2,ma55)<2) return false;
   if(CopyBuffer(ema8Handle,0,0,2,ema8)<2)return false;
   
   //Bullish crossover: 55Ma crosses below all 3
   bool wasAbove=ma55[1]>ma13[1]&&ma55[1]>ma21[1]&&ma55[1]>ema8[1];
   bool nowBelow=ma55[0]<ma13[0]&&ma55[0]<ma21[0]&&ma55[0]<ema8[0];
   return wasAbove&&nowBelow;  
}
//a function to determine a fresh bearish crossover
bool isFreshBearishCrossover()
{
   double ma13[2],ma21[2],ma55[2],ema8[2];
   if(CopyBuffer(ma13Handle,0,0,2,ma13)<2) return false;
   if(CopyBuffer(ma21Handle,0,0,2,ma21)<2) return false;//we check to enrsure that all the two vaues are loaded
   if(CopyBuffer(ma55handle,0,0,2,ma55)<2) return false;
   if(CopyBuffer(ema8Handle,0,0,2,ema8)<2)return false;
   bool wasBelow=ma55[1]<ma13[1]&&ma55[1]<ma21[1]&&ma55[1]<ema8[1];
   bool nowAbove=ma55[0]>ma13[0]&&ma55[0]>ma21[0]&&ma55[0]>ema8[0];
   return wasBelow&&nowAbove;
}
//check if price is less than or equal to 20 pips from the 55ma
bool isPriceNearMa55(double maxDistancePips=20)
{  
  /*get pip size-usually point for most symbols, but for t3-didgits
   or 5-digits brokers, its 10*Point for some forex*/
  double pipSize=(_Digits==3||_Digits==5)?(10*_Point):_Point;
  //create the MA55Handle
  int maHandle=iMA(_Symbol,_Period,55,0,MODE_SMA,PRICE_CLOSE);
  if(maHandle==INVALID_HANDLE)
  {
    Print("failed to create ma Handle");
    return false;     
  }
  //buffer to store the ma handle
  double maBuffer[];
  if(CopyBuffer(maHandle,0,1,1,maBuffer)<=0)
  {
    Print("Failed to copy MA data");
    return false;
  }
  double maValue=maBuffer[0];
  //get the closing price of the previous candle (index 1)
  MqlRates priceInfo[];
  if(CopyRates(_Symbol,_Period,1,1,priceInfo)<=0)
  {
    Print("failed to get price data");
    return false;
  }
  double closePrice=priceInfo[0].close;
  //compare distance in pips
  double pipDiff=MathAbs(closePrice-maValue)/pipSize;
  return (pipDiff<=maxDistancePips);
}
// fuction to find the most recent swing hgh or swing low
double GetRecentSwingHighOrLow(bool isBuy)
{
   const int limit=100;//scan the last 100 candles
   double zzBuffer[];
   double closeBuffer[];
   ArraySetAsSeries(zzBuffer, true);
   ArraySetAsSeries(closeBuffer,true);
   //copy zigzag buffer
   if(CopyBuffer(zigzagHandle,0,0,limit,zzBuffer)<=0)
   {
      Print("Failed to copy zigzag buffer");
      return 0.0;
   }
   //copy close prices
   if(CopyClose(_Symbol,_Period,0,limit,closeBuffer)<=0)
   {
      Print("FAiled to copy close prices");
      return 0.0;
   }
   for(int i=1;i<limit;i++)
   {
      if(zzBuffer[i]!=0.0)
      {
         if(isBuy)
         {
            //for buy, we want the recent swing lowouble
            if(zzBuffer[i]<closeBuffer[i])
               return zzBuffer[i];
         }   
      }
      else
      {
         //for sell, we want recent swing high
         if(zzBuffer[i]>closeBuffer[i])
            return zzBuffer[i];
      }
   }
   return 0.0;//fallback if none found
}

double CalculateStopLossPrice(bool isBuy,double entryPrice,double pipSize)
{
   double swingPoint=GetRecentSwingHighOrLow(isBuy);
   if(swingPoint==0.0)
   {
      Print("No valid swing point found. using default Sl");
      return isBuy ? swingPoint-1*pipSize: swingPoint +1*pipSize;
   }
   double sl=isBuy? swingPoint-1*pipSize:swingPoint+1*pipSize;
   //enforce minimum 20 pips SL
   double minSL =20* pipSize;
   double actualSLDistance=MathAbs(entryPrice-sl);
   if(actualSLDistance<minSL)
   {
      sl=isBuy?entryPrice-minSL:entryPrice+minSL;
   }
   return sl;
}
bool isPriceInGoldenZone(bool isBuy)
{
   double swingHigh=GetRecentSwingHighOrLow(false);
   double swingLow=GetRecentSwingHighOrLow(true);
   double fib382,fib618;
   if(isBuy)
   {
      fib382=swingLow+(swingHigh-swingLow)*0.382;
      fib618=swingLow+(swingHigh-swingLow)*0.618;
   }
   else
   {
      fib382=swingHigh-(swingHigh-swingLow)*0.382;
      fib618=swingHigh-(swingHigh-swingLow)*0.618;    
   }
   double price=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if (isBuy)
      return (price>=fib382&& price<= fib618);
    else
      return (price<=fib382 &&price>=fib618);  
}
bool isBullishEngulfing(int shift=1)
{
   double open1=iOpen(_Symbol,_Period,shift+1);
   double close1=iClose(_Symbol,_Period,shift+1);
   double open2=iOpen(_Symbol,_Period,shift);
   double close2=iClose(_Symbol,_Period,shift);
   return (close1<open1&&close2>open2&&close2>open1&&open2 <close1);
}
bool isBearshEngulfing(int shift=1)
{
   double open1=iOpen(_Symbol,_Period,shift+1);
   double close1=iClose(_Symbol,_Period,shift+1);
   double open2=iOpen(_Symbol,_Period,shift);
   double close2=iClose(_Symbol,_Period,shift);
   return (close1>open1&&close2<open2&&close2<open1&&open2 >close1);
}
bool isTrendContinuationCandles(bool isBuy)
{
   double close0=iClose(_Symbol,_Period,0);
   double close1=iClose(_Symbol,_Period,1);
   double close2=iClose(_Symbol,_Period,2);
   if (isBuy)
      return (close2<close1&&close1<close0); //two higher closes
   else
      return (close2>close1&&close1>close0);//two lower closes   
}
double calculateLotsize(double stopLossPips,double riskPercent=1.0)
{
   double accountBalance=AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount=accountBalance*(riskPercent/100);
   double tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double pointSize=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double lotStep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double pipValuePerLot=(tickValue/pointSize)*10;
   double lotSize=riskAmount/(stopLossPips*pipValuePerLot);
   lotSize=MathFloor(lotSize/lotStep);//round to nearest lot step
   return NormalizeDouble(lotSize,2);
}
bool setTradeSLTP(bool isBuy,double entryPrice,double swingPoint, double rrRatio=3.0)
{
   double sl=MathAbs(entryPrice-swingPoint);
   double minSL=20*_Point;
   if(sl<minSL)
      sl=minSL;
   double tp=sl*rrRatio;
   double stopLoss=isBuy?entryPrice-sl:entryPrice+sl;
   double takeProfit=isBuy?entryPrice+tp:entryPrice-tp;
   //Open trades here.use this sl and tp inthe orderSend() function
   Print("SL: ",DoubleToString(stopLoss,_Digits), "| TP: ",DoubleToString(takeProfit,_Digits));
   return true;
      
}
void MoveToBreakeven(ulong ticket,double entryPrice,double sl, double currentPrice, bool isBuy)
{
   double oneR=MathAbs(entryPrice-sl);
   bool hit1R=isBuy?(currentPrice>=entryPrice+oneR):(currentPrice<=entryPrice-oneR);
   if(hit1R)
   {
      double newSL=entryPrice;
      trade.PositionModify(ticket,newSL,0);
      Print("SL moved to breakeven");
   }
}
void trailStopUsingATR(ulong ticket,bool isBuy)
{
   int atrPeriod=14;
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer,true);
   int atrHandle=iATR(_Symbol,_Period,atrPeriod);
   if(CopyBuffer(atrHandle,0,0,1,atrBuffer)<=0) return;
   double atr=atrBuffer[0];
   double trailDistance=atr*1.5;
   double price=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double newSL=isBuy?price-trailDistance:price+trailDistance;
   trade.PositionModify(ticket,newSL,0);
   Print("Trailing stop adjusted");
}
bool CheckDailyLossLimit(double maxDailyLossPercent=5.0)
{
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   double lossPercent=((balance-equity)/balance)*100.0;
   if(lossPercent>=maxDailyLossPercent)
   {
      Print("Daily loss limit hit:",DoubleToString(lossPercent,2),"%");
      return false;
   }
   return true;
}
bool isCorrelatedPairOpen(string currentSymbol)
{
   string correlatedPairs[]={"EURUSD","GBPUSD","AUDUSD","NZDUSD"};
   for(int i=0;i<ArraySize(correlatedPairs);i++)
   {
      if(currentSymbol==correlatedPairs[i])continue;
      if(PositionSelect(correlatedPairs[i]))
      {
         Print("Correlated pair open: ",correlatedPairs[i]);
         return true;
      }
   }
   return false;
}
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   ma13Handle=iMA(_Symbol,PERIOD_CURRENT,13,0,MODE_SMA,PRICE_CLOSE);
   ma21Handle=iMA(_Symbol,PERIOD_CURRENT,21,0,MODE_SMA,PRICE_CLOSE);
   ma55handle=iMA(_Symbol,PERIOD_CURRENT,55,0,MODE_SMA,PRICE_CLOSE);
   ema8Handle=iMA(_Symbol,PERIOD_CURRENT,8,0,MODE_EMA,PRICE_CLOSE);
   if(ma13Handle==INVALID_HANDLE||ma21Handle==INVALID_HANDLE||ma55handle==INVALID_HANDLE||ema8Handle==INVALID_HANDLE)
   {
    Print("Failed to create MA handles.");
    return(INIT_FAILED); 
   }  
   zigzagHandle=iCustom(_Symbol,PERIOD_CURRENT,"Omosh zigzag",12,5,3);  
   if(zigzagHandle==INVALID_HANDLE)
   {
      Print("Failed to create zigzag Handle");
      return INIT_FAILED;
   }
                     
//---
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if (!isTradingTime() || !CheckDailyLossLimit() || isCorrelatedPairOpen(_Symbol))
      return;

   if (isFreshBullishCrossover() && isPriceNearMa55(MaxDistancePips) &&
       isPriceInGoldenZone(true) && isBullishEngulfing() && isTrendContinuationCandles(true))
   {
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double pipSize = (_Digits == 3 || _Digits == 5) ? 10 * _Point : _Point;
      double sl = CalculateStopLossPrice(true, entry, pipSize);
      double slPips = MathAbs(entry - sl) / pipSize;
      double lotSize = calculateLotsize(slPips, RiskPercent);

      double tp = entry + RRRatio * (entry - sl);

      if (trade.Buy(lotSize, _Symbol, entry, sl, tp, NULL))
      {
         Print("Buy order placed. Entry:", entry, " SL:", sl, " TP:", tp);
      }
   }
   else if (isFreshBearishCrossover() && isPriceNearMa55(MaxDistancePips) &&
            isPriceInGoldenZone(false) && isBearshEngulfing() && isTrendContinuationCandles(false))
   {
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double pipSize = (_Digits == 3 || _Digits == 5) ? 10 * _Point : _Point;
      double sl = CalculateStopLossPrice(false, entry, pipSize);
      double slPips = MathAbs(entry - sl) / pipSize;
      double lotSize = calculateLotsize(slPips, RiskPercent);

      double tp = entry - RRRatio * (sl - entry);

      if (trade.Sell(lotSize, _Symbol, entry, sl, tp, NULL))
      {
         Print("Sell order placed. Entry:", entry, " SL:", sl, " TP:", tp);
      }
   }
}
//+------------------------------------------------------------------+
