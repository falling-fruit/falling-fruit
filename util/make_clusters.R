# Run in Rails - https://quickleft.com/blog/running-r-script-ruby-rails-app/

# install.packages(c("devtools", "data.table"))
# devtools::install_github("RcppCore/Rcpp")
# devtools::install_github("rstats-db/DBI")
# devtools::install_github("rstats-db/RPostgres")
# devtools::install_github("falling-fruit/fruitr")

# ---- Constants ----

args <- commandArgs(TRUE)
Table_owner <- args[1]
Max_grid_zoom <- 13L
DB_driver <- RPostgres::Postgres()
DB_name <- "fallingfruit_new_db"
Table_name <- "clusters"
Created_at <- structure(Sys.time(), tzone = "UTC")

# ---- Get locations ----

db <- DBI::dbConnect(DB_driver, DB_name)
sql <- "SELECT lng, lat, muni, type_ids FROM locations WHERE NOT hidden;"
locations <- data.table::as.data.table(DBI::dbGetQuery(db, sql))
DBI::dbDisconnect(db)

# ---- Expand type ids ----

types <- strsplit(substring(locations$type_ids, 2, nchar(locations$type_ids) - 1), ",")
locations[, type_ids := NULL]
locations <- locations[rep(1:nrow(locations), sapply(types, length))]
locations[, type_id := as.integer(unlist(types))]
# FIXME: few types_ids contain NULL
locations <- locations[!is.na(type_id)]

# ---- Assign to grid cells ----

# Add Web Mercator coordinates
locations[, c("x", "y") := as.data.frame(fruitr::lnglat_to_xy(cbind(lng, lat)))]

# Add Web Mercator grid cell indices
locations[, c("xi", "yi", "zoom") := as.data.frame(fruitr::xy_to_gridcells(cbind(x, y), zoom = Max_grid_zoom))]

# ---- Compute clusters ----

# Build leaf nodes
clusters <- locations[, .(x = mean(x), y = mean(y), count = .N), by = .(xi, yi, type_id, muni, zoom)]

# Compute geohashes
clusters[, geohash := fruitr::gridcells_to_geohashes(cbind(xi, yi, zoom))]

# Expand geohashes
geohashes <- clusters[, fruitr::expand_geohashes(geohash)]
clusters <- clusters[rep(1:.N, nchar(geohash) / 2)]
clusters[, geohash := geohashes]

# Build parent nodes
clusters <- clusters[, .(x = weighted.mean(x, count), y = weighted.mean(y, count), count = sum(count)), by = .(geohash, type_id, muni)]

# Convert Web Mercator to WGS84
# clusters[, c("lng", "lat") := as.data.frame(fruitr::xy_to_lnglat(cbind(x, y)))]
# clusters[, c("x", "y") := NULL]

# Calculate zoom from geohash
clusters[, zoom := fruitr::geohashes_to_zoom(geohash)]

# Add id
clusters[, id := 1:.N]

# Add timestamps
clusters[, c("created_at", "updated_at") := Created_at]

# ---- Write clusters ----

db <- DBI::dbConnect(DB_driver, DB_name)
field_types <- c(
  id = "serial primary key",
  geohash = "text not null",
  type_id = "integer not null",
  muni = "boolean not null",
  x = "real not null",
  y = "real not null",
  # lng = "real not null",
  # lat = "real not null",
  count = "integer not null",
  zoom = "integer not null",
  created_at = "timestamp not null",
  updated_at = "timestamp not null"
)
DBI::dbWriteTable(db, Table_name, clusters, row.names = FALSE, overwrite = TRUE, field.types = field_types)
DBI::dbExecute(db, paste0("ALTER SEQUENCE ", Table_name, "_id_seq RESTART WITH ", nrow(clusters) + 1))
DBI::dbExecute(db, paste0("CREATE INDEX index_", Table_name, "_on_type_id ON ", Table_name, "(type_id)"))
if (!is.na(Table_owner)) {
  DBI::dbExecute(db, paste("ALTER TABLE", Table_name, "OWNER TO", Table_owner))
}
DBI::dbDisconnect(db)
