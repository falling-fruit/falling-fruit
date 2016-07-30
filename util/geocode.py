#!/usr/bin/python
# Retrieve Google Geocoding coordinates for a list of addresses, in the format <Lat>\t<Lng>:
# geocode.py <file>
# <file> is a text file of coordinates in the format "address\n"

# Google Geocoding API
# usage limits: https://developers.google.com/maps/documentation/geocoding/#Limits
# 2,500 requests per day, 10 per second

import sys
import os
import json
import urllib
import urllib2
import time

# default coordinates file, assumed if no argument given
file = os.path.dirname(os.path.realpath(__file__)) + '/addresses.txt'
if len(sys.argv) > 1:
    file = sys.argv[1]

# Google Geocode API
GEOCODE_BASE_URL = 'https://maps.googleapis.com/maps/api/geocode/json'
def getLatLng(address, sensor = 'false', key = 'AIzaSyBB8Abarc_SZdsJoK1C0xAJoXcNC91xHWk'):
	
	geocode_args = {'address': address, 'sensor': sensor}
	url = GEOCODE_BASE_URL + '?' + urllib.urlencode(geocode_args)
	try:
	  response = urllib2.urlopen(url)
	except urllib2.HTTPError, e:
	  print 'ERROR' + '\t' + e.reason
	
	# Parse results
	j = json.load(response)
	status = j['status']
	if status == 'OK':
	  print str(j['results'][0]["geometry"]["location"]["lat"]) + '\t' + str(j['results'][0]["geometry"]["location"]["lng"]) + '\t' + str(j['results'][0]["types"])
	else:
	  print 'ERROR' + '\t' + status
	
# Send single location requests
# (pause inserted to avoid being booted by Google servers)
delay = 250
addresses = [line.rstrip('\n').replace('\t',',') for line in open(file)]
for address in addresses:
	getLatLng(address)
	time.sleep(delay / 1000)