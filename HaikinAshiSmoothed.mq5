//+------------------------------------------------------------------+
//|                                           HaikinAshiSmoothed.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots 1
#property indicator_type1 DRAW_CANDLES
#property  indicator_color1 clrCornflowerBlue
#property indicator_width1 1
//-----input parameters
input int SmoothedPeriod=5 ;//Ema smoothing period
// indicator buffers
double haOpen[];
double haHigh[];
double haLow[];
double haClose[];

// internal buffers for EMA
double emaOpen[];
double emaClose[];
double  k;  //ema multiplier

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
SetIndexBuffer(0,haOpen,INDICATOR_DATA);
SetIndexBuffer(1,haHigh,INDICATOR_DATA);
SetIndexBuffer(2,haLow,INDICATOR_DATA);
SetIndexBuffer(3,haClose,INDICATOR_DATA);

PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,SmoothedPeriod);
IndicatorSetInteger(INDICATOR_DIGITS,_Digits);

//---Allocate EMA helper arrays
ArraySetAsSeries(haOpen,true);
ArraySetAsSeries(haHigh, true);
ArraySetAsSeries(haLow,true);
ArraySetAsSeries(haClose, true);
ArraySetAsSeries(emaOpen, true);
ArraySetAsSeries(emaClose,true);

k=2.0/(SmoothedPeriod+1.0);
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//---
   if(rates_total<SmoothedPeriod+2)return(0);
   int start=prev_calculated>1?prev_calculated-1:1; //recalculate last bar for accuracy
   //-- main loop
   for(int i=start;i<rates_total;i++)
   {
      //calculate raw HA values
      double rawClose=(open[i]+high[i]+low[i]+close[i])/4.0;
      double rawOpen=(i==1)?(open[1]+close[1])/2.0: (haOpen[i-1]+haClose[i-1])/2.0;
      double rawHigh=MathMax(high[i], MathMax(rawOpen, rawClose));
      double rawLow=MathMin(low[i], MathMin(rawOpen, rawClose));
      
      //---first bar (i==1) initial EMA seed
      if(i==1)
      {
         emaClose[i]=rawClose;
         emaOpen[i]=rawOpen;
        q
      }
      else
      {
         //EMA smoothing
         emaClose[i]=(rawClose-emaClose[i-1])* k + emaClose[i-1];
         emaOpen[i]=(rawOpen-emaOpen[i-1]) *k + emaOpen[i-1];
      }
      //write the final smoothed HA candle
      haClose[i]=emaClose[i];
      haOpen[i]=emaOpen[i];
      haHigh[i]=MathMax(rawHigh, MathMax(haOpen[i],haClose[i]));
      haLow[i]=MathMin(rawLow, MathMin(haOpen[i],haClose[i])); 
   }
   
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
