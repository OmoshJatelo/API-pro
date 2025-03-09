import numpy as np
import pandas as pd
import yfinance as yf
import backtrader as bt
import matplotlib.pyplot as plt
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from datetime import datetime

# ✅ Function to Download Forex Data
def get_data(ticker, start="2023-01-01", end="2024-01-01"):
    data = yf.download(ticker, start=start, end=end)

    if data.empty:
        raise ValueError("Downloaded data is empty. Check ticker or date range.")
    
    # Ensure the index is a datetime index
    data.index = pd.to_datetime(data.index)
    
    # Compute Moving Averages for Trend Detection
    data["SMA_50"] = data["Close"].rolling(window=50).mean()
    data["SMA_200"] = data["Close"].rolling(window=200).mean()
    data["Trend"] = np.where(data["SMA_50"] > data["SMA_200"], 1, -1)
    
    # Drop NaN values after adding indicators
    data.dropna(inplace=True)
    
    return data

# ✅ Train Machine Learning Model
def train_ml_model(data):
    X = data[["SMA_50", "SMA_200", "Trend"]]
    y = np.where(data["Close"].shift(-1) > data["Close"], 1, 0)  # Buy = 1, Sell = 0

    # Train-test split to evaluate model performance
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X_train_scaled, y_train.ravel())  # Fix: Flatten 'y' to 1D

    # Evaluate model on test data
    accuracy = model.score(X_test_scaled, y_test) * 100
    print(f"ML Model Test Accuracy: {accuracy:.2f}%")

    return model, scaler

# ✅ Backtrader Strategy
class MLStrategy(bt.Strategy):
    params = (("model", None), ("scaler", None))

    def _init_(self):
        self.model = self.params.model
        self.scaler = self.params.scaler

    def next(self):
        if self.model is None or self.scaler is None:
            return

        # Get the latest data for prediction
        features = np.array([[self.datas[0].SMA_50[0], self.datas[0].SMA_200[0], self.datas[0].Trend[0]]])
        scaled_features = self.scaler.transform(features)
        prediction = self.model.predict(scaled_features)

        # Trading logic
        if prediction == 1 and not self.position:
            self.buy()
        elif prediction == 0 and self.position:
            self.sell()

# ✅ Backtesting Function (Error-Free)
def backtest(data, model, scaler):
    cerebro = bt.Cerebro()
    cerebro.addstrategy(MLStrategy, model=model, scaler=scaler)

    # Set initial cash and commission
    cerebro.broker.set_cash(10000)  # $10,000 initial cash
    cerebro.broker.setcommission(commission=0.001)  # 0.1% commission

    # Convert DataFrame to Backtrader Feed
    # Ensure the DataFrame has the required columns
    data_feed = bt.feeds.PandasData(
        dataname=data,
        datetime=None,  # Use the index as datetime
        open="Open",
        high="High",
        low="Low",
        close="Close",
        volume="Volume",
        openinterest=None,
    )
    cerebro.adddata(data_feed)

    cerebro.run()
    cerebro.plot()

# ✅ Execute the Trading Bot
ticker = "EURUSD=X"  # Use Yahoo Finance format for Forex
data = get_data(ticker)

# Debug: Check the structure of the data
print(type(data))  # Should output <class 'pandas.core.frame.DataFrame'>
print(data.head())  # Check the first few rows

model, scaler = train_ml_model(data)
backtest(data, model, scaler)