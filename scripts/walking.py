# DO NOT USE: The Google Maps API is not free!

import pandas as pd
import geopandas as gpd
import requests
import json
from shapely.geometry import Point
from haversine import haversine, Unit
from dotenv import load_dotenv
import os
load_dotenv()

# read files
cps_schools = pd.read_csv("../data/cps_schools.csv")
cpd_parks = gpd.read_file("../data/cpd_parks.geojson")

geometry = [Point(xy) for xy in zip(cps_schools.Longitude, cps_schools.Latitude)]
cps_schools = gpd.GeoDataFrame(cps_schools, geometry=geometry)

def get_walking_distance(origin, destination, api_key):
    url = f"https://maps.googleapis.com/maps/api/distancematrix/json?units=imperial&origins={origin.y},{origin.x}&destinations={destination.representative_point().y},{destination.representative_point().x}&mode=walking&key={api_key}"
    response = requests.get(url)
    data = json.loads(response.text)
    try:
        response = data['rows'][0]['elements'][0]
        return response['distance']['text'], response['duration']['text']
    except:
        return "ZZZ"

api_key = os.getenv("API_KEY")

# calc walking distance
distances = []
for i in range(len(cps_schools)):
    school = cps_schools.iloc[i]
    print("looking at ", school["School_Name"] )
    min_distance = None
    closest_park = None
    curr_minute = None
    for j in range(len(cpd_parks)):
        park = cpd_parks.iloc[j]
        h_distance = haversine((school.geometry.y, school.geometry.x), (park.geometry.centroid.y, park.geometry.centroid.x), unit=Unit.MILES)
        # only calc distance if haversine distance is less than 2
        if h_distance < 2:
            distance, duration  = get_walking_distance(school.geometry, park.geometry, api_key)
            if min_distance is None or distance < min_distance:
                min_distance = distance
                closest_park = park['park']
                curr_minute = duration
    if closest_park is not None:
        distances.append((school['School_Name'], min_distance,curr_minute,closest_park))
    print((i +1  / len(cps_schools)), "% done")

new_data = pd.DataFrame(distances, columns=['school_name', 'distance_to_nearest_park_miles','duration', 'nearest_park'])

new_data.to_csv("../results/min_distance_to_park.csv", index=False)
