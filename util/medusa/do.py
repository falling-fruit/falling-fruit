from dop.client import Client
import time
import sys

CLIENT_ID = 'wsUidZ0x7MzvUK2IyQ9v2'
API_KEY = 'e9ed43def04bd29c37aed0a5e6d9c5c9'

if __name__ == '__main__':
  client = Client(CLIENT_ID, API_KEY)
  #create a droplet
  conf = {'name': sys.argv[1], 
      'size_id': 66,
      'image_id': 3101918,
      'region_id': 3,
      'ssh_key_ids': ['111705', '115854']}
  droplet = client.create_droplet(**conf)
  is_active = False
  while not is_active:
    time.sleep(2)
    status = client.get_status(droplet.event_id)
    if status.percentage == '100':
      is_active = True
      print "Droplet Created."
      print client.show_droplet(droplet.id).__dict__
