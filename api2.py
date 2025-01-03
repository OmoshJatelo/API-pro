
import requests
response=requests.post("https://dummyapi.io/data/v1/user/create",
headers={
    "app-id": "62b0433d2dfd91d4bf56c584"

},
data={
    "firstName": "James",
    "lastName": "Shelby",
    "email": "jamesshelbys6567764@dusmdemsy.com"
}
)



print(response.status_code)
print(response.json()["firstName"])
print(response.json()["lastName"])

for x in response.json():
    print(x)

#post method requires the parameters: url, header,data    