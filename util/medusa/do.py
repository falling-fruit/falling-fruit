from dop.client import Client
import time
import sys
import yaml

if __name__ == '__main__':
  yaml = yaml.load(open('ansible-provision/secret_vars.yml','r'))
  client = Client(yaml['doid'], yaml['dokey'])
  #create a droplet
  conf = {'name': sys.argv[1], 
      'size_id': 66,
      'image_id': 3101918,
      'region_id': 3,
      'ssh_key_ids': ['20319']}
  droplet = client.create_droplet(**conf)
  is_active = False
  while not is_active:
    time.sleep(2)
    status = client.get_status(droplet.event_id)
    if status.percentage == '100':
      is_active = True
      print "Droplet Created."
      print client.show_droplet(droplet.id).__dict__
