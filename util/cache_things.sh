for i in $(seq 4 15);do
  for m in $(seq 0 1);do
    wget -q -O - "http://new.fallingfruit.org/locations/cluster.json?muni=$m&method=grid&grid=$i" > /dev/null
  done
done
