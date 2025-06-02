//+------------------------------------------------------------------+ //|                                             SmartTraderEA.mq5    | //|                      Advanced MAs + Top-Down Strategy            | //|                        with ADX, Logging, Trailing Stop,         | //|                          Break-Even, and Dashboard               | //+------------------------------------------------------------------+ #property strict

input double LotSize = 0.01; input int MaxTrades = 6; input int MaxTradesPerPair = 2; input double ATRMultiplier = 1.5; input double MaxSignalDistancePips = 20; input int StopBeforeMarketCloseMinutes = 15; input ENUM_TIMEFRAMES HTF = PERIOD_H1; input ENUM_TIMEFRAMES SignalTF = PERIOD_M5; input double TrailingStopPips = 20; input double BreakEvenPips = 30; input double BreakEvenBuffer = 5;

//--- Indicator handles int ma13_handle, ma21_handle, ma55_handle, ema_handle; int atr_handle, adx_handle;

//+------------------------------------------------------------------+ //| Expert initialization function                                   | //+------------------------------------------------------------------+ int OnInit() { ma13_handle = iMA(_Symbol, SignalTF, 13, 0, MODE_SMA, PRICE_CLOSE); ma21_handle = iMA(_Symbol, SignalTF, 21, 0, MODE_SMA, PRICE_CLOSE); ma55_handle = iMA(_Symbol, SignalTF, 55, 0, MODE_SMA, PRICE_CLOSE); ema_handle  = iMA(_Symbol, SignalTF, 8, 0, MODE_EMA, PRICE_CLOSE); atr_handle  = iATR(_Symbol, SignalTF, 14); adx_handle  = iADX(_Symbol, SignalTF, 14);

if(ma13_handle == INVALID_HANDLE || ma21_handle == INVALID_HANDLE || ma55_handle == INVALID_HANDLE || ema_handle == INVALID_HANDLE || atr_handle == INVALID_HANDLE || adx_handle == INVALID_HANDLE) { Print("Failed to create indicator handles"); return INIT_FAILED; } return INIT_SUCCEEDED; }

//+------------------------------------------------------------------+ //| Expert tick function                                             | //+------------------------------------------------------------------+ void OnTick() { UpdateTrailingStops(); CheckBreakEven();

MqlDateTime timeStruct; TimeToStruct(TimeCurrent(), timeStruct); int day = timeStruct.day_of_week; int hour = timeStruct.hour; int minute = timeStruct.min;

if((day == 5 && (hour * 60 + minute >= (1440 - StopBeforeMarketCloseMinutes))) || day == 6 || day == 0) { if(!IsCrypto(_Symbol)) return; }

double ma13_arr[1], ma21_arr[1], ma55_arr[1], ema_arr[1], atr_arr[1], adx_arr[1]; if(CopyBuffer(ma13_handle, 0, 0, 1, ma13_arr) < 0 || CopyBuffer(ma21_handle, 0, 0, 1, ma21_arr) < 0 || CopyBuffer(ma55_handle, 0, 0, 1, ma55_arr) < 0 || CopyBuffer(ema_handle,  0, 0, 1, ema_arr) < 0 || CopyBuffer(atr_handle,  0, 0, 1, atr_arr) < 0 || CopyBuffer(adx_handle, 0, 0, 1, adx_arr) < 0) { Print("Error loading indicator values"); return; }

double ma13 = ma13_arr[0]; double ma21 = ma21_arr[0]; double ma55 = ma55_arr[0]; double ema  = ema_arr[0]; double atr  = atr_arr[0]; double adx  = adx_arr[0]; double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

double signal_distance_pips = MathAbs(price - ma55) / _Point / 10; if(signal_distance_pips > MaxSignalDistancePips && signal_distance_pips > atr * ATRMultiplier / _Point) return;

if(adx < 20) { Print("ADX too low. No trend"); return; }

if(!TopDownTrendFilter()) return;

if(ma55 < ma13 && ma55 < ma21 && ma55 < ema && CountTrades(_Symbol) < MaxTradesPerPair && TotalOpenTrades() < MaxTrades) { OpenTrade(ORDER_TYPE_BUY, price); } else if(ma55 > ma13 && ma55 > ma21 && ma55 > ema && CountTrades(_Symbol) < MaxTradesPerPair && TotalOpenTrades() < MaxTrades) { OpenTrade(ORDER_TYPE_SELL, price); } }

//+------------------------------------------------------------------+ //| Check HTF trend for confirmation                                 | //+------------------------------------------------------------------+ bool TopDownTrendFilter() { double ma55_HTF[1], ma13_HTF[1], ma21_HTF[1], ema_HTF[1];

int h_ma55 = iMA(_Symbol, HTF, 55, 0, MODE_SMA, PRICE_CLOSE); int h_ma13 = iMA(_Symbol, HTF, 13, 0, MODE_SMA, PRICE_CLOSE); int h_ma21 = iMA(_Symbol, HTF, 21, 0, MODE_SMA, PRICE_CLOSE); int h_ema  = iMA(_Symbol, HTF, 8, 0, MODE_EMA, PRICE_CLOSE);

if(CopyBuffer(h_ma55, 0, 0, 1, ma55_HTF) < 0 || CopyBuffer(h_ma13, 0, 0, 1, ma13_HTF) < 0 || CopyBuffer(h_ma21, 0, 0, 1, ma21_HTF) < 0 || CopyBuffer(h_ema,  0, 0, 1, ema_HTF) < 0) return false;

return (ma55_HTF[0] < ma13_HTF[0] && ma55_HTF[0] < ma21_HTF[0] && ma55_HTF[0] < ema_HTF[0]) || (ma55_HTF[0] > ma13_HTF[0] && ma55_HTF[0] > ma21_HTF[0] && ma55_HTF[0] > ema_HTF[0]); }

//+------------------------------------------------------------------+ //| Open Trade Function                                              | //+------------------------------------------------------------------+ void OpenTrade(int orderType, double price) { double sl, tp;

if(orderType == ORDER_TYPE_BUY) { sl = price - 50 * _Point; tp = price + 150 * _Point; } else { sl = price + 50 * _Point; tp = price - 150 * _Point; }

MqlTradeRequest request = {}; MqlTradeResult result = {};

request.symbol = _Symbol; request.volume = LotSize; request.type = orderType; request.action = TRADE_ACTION_DEAL; request.price = price; request.sl = sl; request.tp = tp; request.magic = 123456; request.deviation = 5;

if(!OrderSend(request, result)) { Print("OrderSend failed: ", result.retcode); } else { Print("Trade opened: ", (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL"), " @ ", price); } }

//+------------------------------------------------------------------+ //| Trailing Stop Function                                          | //+------------------------------------------------------------------+ void UpdateTrailingStops() { for(int i = 0; i < PositionsTotal(); i++) { if(PositionGetTicket(i) > 0) { string symbol = PositionGetString(POSITION_SYMBOL); if(symbol != _Symbol) continue;

double price = SymbolInfoDouble(symbol, POSITION_TYPE == POSITION_TYPE_BUY ? SYMBOL_BID : SYMBOL_ASK);
     double open = PositionGetDouble(POSITION_PRICE_OPEN);
     double sl = PositionGetDouble(POSITION_SL);

     if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
     {
        if(price - open >= TrailingStopPips * _Point && sl < price - TrailingStopPips * _Point)
        {
           sl = price - TrailingStopPips * _Point;
           ModifySL(sl);
        }
     }
     else
     {
        if(open - price >= TrailingStopPips * _Point && sl > price + TrailingStopPips * _Point)
        {
           sl = price + TrailingStopPips * _Point;
           ModifySL(sl);
        }
     }
  }

} }

void ModifySL(double sl) { MqlTradeRequest request = {}; MqlTradeResult result = {};

request.action = TRADE_ACTION_SLTP; request.sl = sl; request.symbol = _Symbol;

OrderSend(request, result); }

//+------------------------------------------------------------------+ //| Break-Even Check                                                | //+------------------------------------------------------------------+ void CheckBreakEven() { for(int i = 0; i < PositionsTotal(); i++) { if(PositionGetTicket(i) > 0) { double open = PositionGetDouble(POSITION_PRICE_OPEN); double price = SymbolInfoDouble(_Symbol, SYMBOL_BID); double sl = PositionGetDouble(POSITION_SL);

if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
     {
        if(price - open >= BreakEvenPips * _Point && sl < open)
        {
           ModifySL(open + BreakEvenBuffer * _Point);
        }
     }
     else
     {
        price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        if(open - price >= BreakEvenPips * _Point && sl > open)
        {
           ModifySL(open - BreakEvenBuffer * _Point);
        }
     }
  }

} }

//+------------------------------------------------------------------+ //| Count Open Trades                                                | //+------------------------------------------------------------------+ int CountTrades(string symbol) { int count = 0; for(int i = 0; i < PositionsTotal(); i++) { if(PositionGetSymbol(i) == symbol) count++; } return count; }

int TotalOpenTrades() { return PositionsTotal(); }

//+------------------------------------------------------------------+ //| Detect if Symbol is Crypto                                       | //+------------------------------------------------------------------+ bool IsCrypto(string symbol) { return(StringFind(symbol, "BTC") >= 0 || StringFind(symbol, "ETH") >= 0 || StringFind(symbol, "USDT") >= 0); } //+------------------------------------------------------------------+

