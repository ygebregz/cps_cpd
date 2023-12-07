import pandas as pd
import requests
from dotenv import load_dotenv
import os
load_dotenv()

def get_lat_long(api_key, school_name):
    base_url = "https://maps.googleapis.com/maps/api/geocode/json"
    params = {
        "address": school_name,
        "key": api_key,
    }
    response = requests.get(base_url, params=params)
    data = response.json()

    if data["status"] == "OK" and data.get("results"):
        location = data["results"][0]["geometry"]["location"]
        latitude = location["lat"]
        longitude = location["lng"]
        return latitude, longitude
    else:
        return None

api_key = os.getenv("API_KEY")
csv_file = 'combined.csv'

df = pd.read_csv(csv_file)

df['Latitude'] = None
df['Longitude'] = None

for index, row in df.iterrows():
    school_name = row['School Name'] + " chicago"
    result = get_lat_long(api_key, school_name)
    print(school_name)
    
    if result:
        df.at[index, 'Latitude'] = result[0]
        df.at[index, 'Longitude'] = result[1]

df.to_csv('gmaps_updated.csv', index=False)

