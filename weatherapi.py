city_name=input("Hello! Welcome to the Great Jatelo Weather Master\nWhich city would you like to check its condition:")
import requests
response=requests.get("https://api.openweathermap.org/data/2.5/weather",
params={"appid":"3b786d5e859b0de56ff43a038bd7c217","q":{city_name}})   # q stands for query q: The city name, "Nairobi," which specifies that you are requesting data for Nairobi
if response.status_code!=200:
    print(f"Oops! ",response.json()["message"])
else:     
    data=response.json() #response.json() parses the JSON data returned by the API into a Python dictionary (data). 



    country=data["sys"]["country"]     #data["sys"]["country"]: Extracts the country code (e.g., "KE" for kenya) from the sys key in the JSON response.
    city=data["name"]       #data["name"]: Extracts the city name (e.g., "NAirobi ") from the name key in the JSON response
    weather_description=data["weather"][0]["description"]
    current_temp=data["main"]["temp"]-273
    max_temp=data["main"]["temp_max"]-273 #convert to degrees
    min_temp=data["main"]["temp_min"]-273
    humidity=data["main"]["humidity"]
    pressure=data["main"]["pressure"]
    wind_speed=data["wind"]["speed"]
    height=data["main"]["sea_level"]



    print(f"\nHere are some useful weather information about {city_name}\n")
    #print(response.status_code)
    print(f"country code: {country}")
    print(f"City name:{city}")
    print(f"Appearence:{weather_description}")
    print(f"Current temperature:{current_temp:.2f}°C")
    print(f"maximum temperature:{max_temp:.2f}°C")
    print(f"minimum temperature:{min_temp:.2f}°C")
    print(f"humidity:{humidity}%")
    print(f"height above sea level:{height} m")
    print(f"Atmospheric pressure:{pressure} atm")
    print(f"Wind speed:{wind_speed} m/s")

    #print(data)
