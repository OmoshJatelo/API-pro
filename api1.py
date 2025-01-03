# Write code here
import requests
response=requests.get("https://dummyapi.io/data/v1/user/",
headers={
    "app-id": "62b0433d2dfd91d4bf56c584"

})
 
for x in range(10):
    data=response.json()["data"][x]
    print(data["id"])

# Manipulating requests Response

# Once you either get() or post() into an API, you will receive a response object which we stored in the response variable in our last examples.


# As we learned in the JSON lesson, these responses are in JSON format or in Python's native dictionary format.

 

# To receive the JSON format of your response. You have to say,

# data = response.json()

# You can then parse through the necessary values in the response, using the keying method of the dictionary