import pandas as pd
#dictionary for holding market data 
market_data={
    'Date':['2024-02-01','2024-02-02','2024-02-03'],
    'Open':[165,167,175],
    'Close':[167,179,171],
    'High':[173,196,191],
    'Low':[155,149,161],
    'volume':[1000,2354,4794]
}
#converting the dictionary into a data frame
data_frame=pd.DataFrame(market_data)
print(data_frame)
#display only the market highs
print(data_frame['High'])
#display the market highs and volume
print(data_frame[['High','volume']])

#ADDING A COLUMN TO THE DATA FRAME
data_frame['DAily return']=data_frame['Close'].pct_change()#percentage change.it calculates btw two days
print(data_frame)
#adding a fifty day moving average
data_frame['SMA-50']=data_frame['Close'].rolling(window=50).mean()#tells pandas to take the first 50 daily closes, compute the mean and repeat the process
print(data_frame)
     
#reading data from a csv file
try:
    read_file=pd.read_csv("stock.csv")
    print(read_file.head())#display the first five rows
except FileNotFoundError:
    print("the file does not exist")
else:
    print("oops! couldnt opne file. an error ocurred")        

#data_frame.to_csv("modified_data_frame.csv",index=False) converting a data frame to a csv file\