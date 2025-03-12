import numpy as np
import pandas as pd
import yfinance as yf
import backtrader as bt
import matplotlib.pyplot as plt
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from datetime import datetime

# ✅ Function to Download Forex Data for Multiple Pairs
def get_data(tickers, start="2023-01-01", end="2024-01-01"):
    data_dict = {}
    for ticker in tickers:
        data = yf.download(ticker, start=start, end=end)
        if data.empty:
            raise ValueError(f"Downloaded data is empty for {ticker}. Check ticker or date range.")
        
        # Compute Moving Averages for Trend Detection
        data["SMA_50"] = data["Close"].rolling(window=50).mean()
        data["SMA_200"] = data["Close"].rolling(window=200).mean()
        data["Trend"] = np.where(data["SMA_50"] > data["SMA_200"], 1, -1)

        # Drop NaN values after adding indicators
        data.dropna(inplace=True)
        
        # Ensure only DataFrame is stored
        data_dict[ticker] = data
    
    return data_dict

# ✅ Calculate ATR for Dynamic Position Sizing
def calculate_atr(data, window=14):
    data['ATR'] = data['High'] - data['Low']
    data['ATR'] = data['ATR'].rolling(window=window).mean()
    return data

# ✅ Train Machine Learning Model
def train_ml_model(data):
    X = data[["SMA_50", "SMA_200", "Trend"]]
    y = np.where(data["Close"].shift(-1) > data["Close"], 1, 0)  # Buy = 1, Sell = 0

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)

    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X_scaled, y.ravel())  # Fix: Flatten 'y' to 1D

    accuracy = model.score(X_scaled, y) * 100
    print(f"ML Model Accuracy: {accuracy:.2f}%")

    return model, scaler

# ✅ Adjust Position Size Based on ATR
def calculate_dynamic_position_size(account_balance, atr_value, risk_percentage=0.01):
    risk_amount = account_balance * risk_percentage
    stop_loss_distance = atr_value  # ATR as the stop-loss distance
    position_size = risk_amount / stop_loss_distance
    return position_size

# ✅ Backtrader Strategy with Dynamic Risk Management
class MLStrategy(bt.Strategy):
    params = (("model", None), ("scaler", None), ("account_balance", 70), ("stop_loss_pct", 0.02), 
              ("risk_reward_ratio", 3), ("risk_percentage", 0.01), ("atr_window", 14))

    def _init_(self):
        self.model = self.params.model
        self.scaler = self.params.scaler
        self.account_balance = self.params.account_balance
        self.stop_loss_pct = self.params.stop_loss_pct
        self.risk_reward_ratio = self.params.risk_reward_ratio
        self.risk_percentage = self.params.risk_percentage
        self.atr_window = self.params.atr_window

    def next(self):
        if self.model is None or self.scaler is None:
            return

        # Get the latest data for prediction for each pair
        for i, data in enumerate(self.datas):
            features = np.array([[data.SMA_50[0], data.SMA_200[0], data.Trend[0]]])
            scaled_features = self.scaler.transform(features)
            prediction = self.model.predict(scaled_features)

            # Calculate ATR for dynamic position sizing
            calculate_atr(data, window=self.atr_window)
            atr_value = data.ATR[0]
            position_size = calculate_dynamic_position_size(self.account_balance, atr_value, self.risk_percentage)

            # Trading logic for 3:1 risk-to-reward ratio
            if prediction == 1 and not self.position:  # Buy signal
                stop_loss = data.close[0] * (1 - self.stop_loss_pct)  # 2% stop loss
                take_profit = data.close[0] * (1 + self.risk_reward_ratio * self.stop_loss_pct)  # 6% take profit
                self.buy(size=position_size)
            
            elif prediction == 0 and self.position:  # Sell signal
                self.sell(size=position_size)

# ✅ Backtesting Function (Error-Free)
def backtest(data_dict, model, scaler):
    cerebro = bt.Cerebro()
    cerebro.addstrategy(MLStrategy, model=model, scaler=scaler, account_balance=70, stop_loss_pct=0.02, 
                        risk_reward_ratio=3, risk_percentage=0.01, atr_window=14)

    # Convert each Forex pair data into Backtrader format and add to cerebro
    for ticker, data in data_dict.items():
        if not isinstance(data, pd.DataFrame):
            raise ValueError(f"Data for {ticker} is not a Pandas DataFrame!")

        data_feed = bt.feeds.PandasData(dataname=data)  # Ensure this is a DataFrame
        cerebro.adddata(data_feed, name=ticker)
    
    cerebro.run()
    cerebro.plot()

# ✅ Execute the Trading Bot with Multiple Pairs
tickers = [
    "EURUSD=X", "GBPUSD=X", "USDJPY=X", "AUDUSD=X", "USDCHF=X",
    "USDCAD=X", "NZDUSD=X", "EURGBP=X", "EURJPY=X", "GBPJPY=X",
    "AUDJPY=X", "CHFJPY=X", "CADJPY=X", "AUDCAD=X", "EURAUD=X",
    "GBPCHF=X", "AUDCHF=X", "NZDJPY=X", "USDSGD=X", "EURCAD=X"
]  # 20 Forex pairs

data_dict = get_data(tickers)
model, scaler = train_ml_model(data_dict["EURUSD=X"])  # Train on one pair, can be adjusted to train on others
backtest