#!/usr/bin/env bash
bees up -s 4 -g bees -k bees2 -i ami-7a836512 -l ec2-user 
bees attack -n 10000 -c 100 -u http://fallingfruit.org/
bees down
