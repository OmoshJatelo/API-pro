//+------------------------------------------------------------------+
//|                                                     SMAalgoX.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com 
//|                               Modular 55_SMa Crossover strategy
//                                   by Omosh Jatelo
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Omosh Jatelo"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh> //allows us to send buy and sell orderes
CTrade trade;  //creates an object for placing and  managing trades

// strategy inputs
input int SMA_Fast1_Period=13;
input int SMA_Fast2_Period=21;
input int SMA_Slow_Period=55;
input int ATR_Period=14;
input double ATR_Multiplier=2.0;
input double RiskRewardRatio=3.0;
input double BreakEvenRR=1.5;
input double LotSize=0.01;
input int MaxConfirmBars=10;
input bool IsryptoPair=false; //set to true for BTCUSDT etc (24/7 execution)

// indicators handles
// these hold references to our moving averages and Atr indicator
int smaFast1Handle;   // for 13 sma
int smaFast2Handle;   //fo  21 sma
int smaSlowHandle;  //for 55 sma
int atrHandle;

// global variables to track strategy state
bool buySignalActive =false; //buy signal waiting
bool sellSignalActive=false;// sell signal waiting
bool tradedBuy= false; // did we trade buy afterr the last buy crosssover?
bool tradedSell=false; // did we trade sell after the last sell crossover?
datetime lastBuyCrosssoverTime=0; //when the 55 sma crossed below fast sma
datetime lastSellCrossoverTime=0;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   // create handles foethe 3 smas and the ATR
   smaFast1Handle=iMA(_Symbol,_Period,SMA_Fast1_Period,0,MODE_SMA,PRICE_CLOSE);
   smaFast2Handle=iMA(_Symbol,_Period,SMA_Fast2_Period,0,MODE_SMA,PRICE_CLOSE);
   smaSlowHandle=iMA(_Symbol,_Period,SMA_Slow_Period,0,MODE_SMA,PRICE_CLOSE);
   atrHandle=iATR(_Symbol,_Period,ATR_Period);
   // check if any indicator failed to initialize
   if(smaFast1Handle==INVALID_HANDLE||smaFast2Handle==INVALID_HANDLE||smaSlowHandle==INVALID_HANDLE||atrHandle==INVALID_HANDLE)
   {
      Print("failed to create one or more indicator handles");
      return INIT_FAILED;
      
   }
   Print("SMAalgoX initialized successfully");
   
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
//---
   //avoid trading during the resricted times(weekends, friday close etc
      if(!isTradingTime())
         return;
      //if we already have a positio open, manage it
      if(PositionSelect(_Symbol))
      {
         CheckForceExit();//exit if MAs reverse
         CheckTimeToForceClose();//exit before friday market close
       }
      // Look for new trading opportunities  
      CheckSignals();
      //adjust stoploss to breakeven ifpricemoves favourably
      ManageOpenTrade();ww¬   qhgE
   
  }
//+------------------------------------------------------------------+

