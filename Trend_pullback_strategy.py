import yfinance as yf
import backtrader as bt
import matplotlib.pyplot as plt

# List of 20 currency pairs (majors and minors)
pairs = [
    'EURUSD=X', 'GBPUSD=X', 'USDJPY=X', 'AUDUSD=X', 'USDCAD=X', 'USDCHF=X', 'NZDUSD=X',
    'EURJPY=X', 'GBPJPY=X', 'AUDJPY=X', 'EURGBP=X', 'USDTRY=X', 'EURAUD=X', 'GBPAUD=X',
    'AUDNZD=X', 'EURNZD=X', 'NZDJPY=X', 'CADJPY=X', 'CHFJPY=X', 'XAUUSD=X'
]

# Define the Trend-Pullback Strategy Class
class TrendPullback(bt.Strategy):
    # Define the indicators
    params = (
        ('ema_short', 50),
        ('ema_long', 200),
        ('rsi_period', 14),
        ('atr_period', 14),
        ('risk_per_trade', 0.01),  # 1% risk per trade
        ('reward_ratio', 3),  # 1:3 Risk to Reward
    )
    
    def __init__(self):
        # Add the indicators to the strategy
        self.ema_short = bt.indicators.ExponentialMovingAverage(self.data.close, period=self.params.ema_short)
        self.ema_long = bt.indicators.ExponentialMovingAverage(self.data.close, period=self.params.ema_long)
        self.rsi = bt.indicators.RelativeStrengthIndex(period=self.params.rsi_period)
        self.atr = bt.indicators.AverageTrueRange(period=self.params.atr_period)

    def next(self):
        # Skip if not enough data to calculate indicators
        if len(self) < max(self.params.ema_short, self.params.ema_long):
            return
        
        # Buy signal: EMA50 above EMA200, RSI below 40 (pullback)
        if self.ema_short > self.ema_long and self.rsi < 40:
            stop_loss = self.data.close[0] - (self.atr[0] * 1.2)  # SL: ATR-based
            take_profit = self.data.close[0] + (self.atr[0] * self.params.reward_ratio)  # TP: 1:3 R:R
            self.buy(
                exectype=bt.Order.Market,
                stopprice=stop_loss,
                limitprice=take_profit
            )
        
        # Sell signal: EMA50 below EMA200, RSI above 60 (pullback)
        elif self.ema_short < self.ema_long and self.rsi > 60:
            stop_loss = self.data.close[0] + (self.atr[0] * 1.2)  # SL: ATR-based
            take_profit = self.data.close[0] - (self.atr[0] * self.params.reward_ratio)  # TP: 1:3 R:R
            self.sell(
                exectype=bt.Order.Market,
                stopprice=stop_loss,
                limitprice=take_profit
            )

# Download data for each currency pair
def get_data(pair):
    data = yf.download(pair, start='2010-01-01', end='2025-01-01', progress=False)
    data['datetime'] = data.index
    data = bt.feeds.PandasData(dataname=data)
    return data

# Initialize the backtest engine
cerebro = bt.Cerebro()

# Add the strategy to the backtest engine
cerebro.addstrategy(TrendPullback)

# Add data for all currency pairs
for pair in pairs:
    data = get_data(pair)
    cerebro.adddata(data, name=pair)

# Set the initial cash and position size for backtesting
cerebro.broker.set_cash(100000)  # Start with $100,000
cerebro.broker.set_commission(commission=0.0005)  # Transaction cost
cerebro.addsizer(bt.sizers.FixedSize, stake=10)  # Set the number of units to buy/sell

# Set the slippage and margin settings (optional, depending on broker)
cerebro.broker.set_slippage_perc(0.001)  # Example: 0.1% slippage

# Set the initial capital and other risk parameters
cerebro.broker.set_cash(100000)
cerebro.broker.set_value(100000)

# Print out the starting cash
print('Starting Portfolio Value: %.2f' % cerebro.broker.getvalue())

# Run the strategy
results = cerebro.run()

# Print out the final portfolio value
print('Ending Portfolio Value: %.2f' % cerebro.broker.getvalue())

# Plot the results
cerebro.plot()
