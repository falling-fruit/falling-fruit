# Run in Rails - https://quickleft.com/blog/running-r-script-ruby-rails-app/

#################
## Load locations

library(DBI)
library(data.table)

# Connect to the database
db <- dbConnect(RPostgres::Postgres(), dbname = "fallingfruit_new_db")

# Retrieve location data
creation_time <- format(Sys.time(), tz = "UTC", "%Y-%m-%d %H:%M:%OS3")
result_id <- dbSendQuery(db, "SELECT lat, lng, muni, type_ids FROM locations;")
locations <- as.data.table(dbFetch(result_id))
dbClearResult(result_id)

## Compute clusters

# Assign grid cells
locations[, c("xi", "yi") := latlng_to_gridcell(lat, lng)]

# Expand type_ids
types <- strsplit(substring(locations$type_ids, 2, nchar(locations$type_ids) - 1), ",")
locations <- locations[rep(1:nrow(locations), sapply(types, length))]
locations[, type_id := as.integer(unlist(types))]

# Build leaf nodes
clusters <- locations[, .(lat = mean(lat), lng = mean(lng), count = .N), by = .(xi, yi, type_id, muni)]

# Compute geohashes
clusters[, geohash := gridcell_to_geohash(list(xi, yi))]

# Expand geohashes
geohashes <- expand_geohashes(clusters$geohash)
clusters <- clusters[rep(1:nrow(clusters), sapply(geohash, nchar) / 2)]
clusters[, geohash := geohashes]

# Build parent nodes
clusters <- clusters[, .(lat = weighted.mean(lat, count), lng = weighted.mean(lng, count), count = sum(count)), by = .(geohash, type_id, muni)]

# Add additional fields
clusters[, zoom := as.integer((nchar(geohash) / 2) - 1)]

## Write clusters

# Write table
dbRemoveTable(db, "new_clusters")
dbWriteTable(db, "new_clusters", as.data.frame(clusters), row.names = FALSE)
# Format table
dbSendQuery(db, "ALTER TABLE new_clusters ADD COLUMN id SERIAL PRIMARY KEY;")
dbSendQuery(db, paste0(
  "ALTER TABLE new_clusters ADD COLUMN created_at TIMESTAMP;",
  "UPDATE new_clusters SET created_at = to_timestamp('", creation_time, "', 'YYYY-MM-DD hh24:mi:ss')::timestamp without time zone;",
  "ALTER TABLE new_clusters ALTER COLUMN created_at SET NOT NULL;"
))
dbSendQuery(db, paste0(
  "ALTER TABLE new_clusters ADD COLUMN updated_at TIMESTAMP;",
  "UPDATE new_clusters SET updated_at = to_timestamp('", creation_time, "', 'YYYY-MM-DD hh24:mi:ss')::timestamp without time zone;",
  "ALTER TABLE new_clusters ALTER COLUMN updated_at SET NOT NULL;"
))

# Close the database connection
dbDisconnect(db)
