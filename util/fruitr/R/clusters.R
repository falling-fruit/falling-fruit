#' Convert Integers to Strings
#'
#' Converts integers to strings according to the given base and the number of digits. Shorter strings are right-padded with zero. Reverse with base::strtoi().
#'
#' @export
#' @family cluster functions
#' @examples
#' itostr(123, base = 2)
#' strtoi(itostr(123), base = 2)
itostr <- function(x, base = 2, n_bits = 32) {
  binary <- function(x) { if (all(x < base)) x else paste(binary(x %/% base), x %% base, sep = "") }
  sprintf(paste0("%0", n_bits, "s"), binary(x))
}

#' Convert Lat,Lng to Grid Cell Indices
#'
#' @export
#' @family cluster functions
#' @examples
#' latlng_to_gridcells(-45, -45, 1)
#' latlng_to_gridcells(45, -45, 1)
#' latlng_to_gridcells(45, 45, 1)
#' latlng_to_gridcells(-45, 45, 1)
latlng_to_gridcells <- function(lat, lng, grid_zoom) {
  # WGS84 (SRID 4326) -> Web Mercator (SRID 900913)
  x <- (lng / 360) * Earth_circumference
  y <- log(tan((lat + 90) * (pi / 360))) * Earth_radius
  # Move origin to bottom left corner
  x <- x + (Earth_circumference / 2)
  y <- y + (Earth_circumference / 2)
  # Convert to grid cell number
  cell_size <- Earth_circumference / (2 ^ grid_zoom)
  xi <- floor(x / cell_size)
  yi <- floor(y / cell_size)
  return(cbind(xi, yi, zi = grid_zoom))
}

#' Convert Grid Cell Indices to Geohash
#'
#' @export
#' @family cluster functions
#' @examples
#' gridcells_to_geohashes(cbind(0, 1, 1))
gridcells_to_geohashes <- function(grid_cells) {
  # Convert to binary
  xb <- itostr(grid_cells[, 1], base = 2, n_bits = grid_cells[, 3] + 1)
  yb <- itostr(grid_cells[, 2], base = 2, n_bits = grid_cells[, 3] + 1)
  # Build hash
  geohashes <- apply(cbind(strsplit(xb, ""), strsplit(yb, "")), 1, function(x) {
    paste0(c(rbind(x[[1]], x[[2]])), collapse = "")
  })
  return(geohashes)
}

#' Convert Grid Cell Index to Geohash
#'
#' @export
#' @family cluster functions
#' @examples
#' latlng_to_geohashes(12.34, 153.21, 0)
#' latlng_to_geohashes(12.34, 153.21, 1)
#' latlng_to_geohashes(12.34, 153.21, 2)
#' latlng_to_geohashes(12.34, 153.21, 13)
latlng_to_geohashes <- function(lat, lng, grid_zoom) {
  geohashes <- gridcells_to_geohashes(latlng_to_gridcells(lat, lng, grid_zoom))
  return(geohashes)
}

#' Convert Geohashes to Lat, Lng
#'
#' @export
#' @family cluster functions
#' @examples
#' geohashes_to_latlng(c("0000", "00"))
#' geohashes_to_latlng(latlng_to_geohashes(12.34, 153.21, 0))
#' geohashes_to_latlng(latlng_to_geohashes(12.34, 153.21, 13))
#' geohashes_to_latlng(latlng_to_geohashes(12.34, 153.21, 31))
geohashes_to_latlng <- function(geohashes) {
  # Expand hash to binary
  xb <- gsub("(.).", "\\1", geohashes)
  yb <- gsub(".(.)", "\\1", geohashes)
  # Convert to integer
  xi <- strtoi(xb, base = 2)
  yi <- strtoi(yb, base = 2)
  # Convert to meters
  grid_zoom <- (nchar(geohashes) / 2) - 1
  grid_cell_size <- Earth_circumference / (2 ^ grid_zoom)
  x <- xi * grid_cell_size
  y <- yi * grid_cell_size
  # Move origin to center
  x <- x - (Earth_circumference / 2)
  y <- y - (Earth_circumference / 2)
  # Web Mercator (SRID 900913) -> WGS84 (SRID 4326)
  lng <- x * (360 / Earth_circumference)
  lat <- 90 - (atan2(1, exp(y / Earth_radius)) * (360 / pi))
  return(list(lat = lat, lng = lng))
}

#' Expand Geohashes
#'
#' @export
#' @family cluster functions
#' @examples
#' expand_geohashes("0011")
#' expand_geohashes(c("0011", "110011"))
#' geohashes_to_latlng(expand_geohashes(latlng_to_geohashes(12.34, 153.21, 31)))
expand_geohashes <- function(geohashes) {
  rows <- 1:length(geohashes)
  lengths <- nchar(geohashes)
  subset_lengths <- seq(max(lengths) - 2, 2, by = -2)
  expanded <- c(geohashes, unlist(sapply(subset_lengths, function(subset_length) {
    ind <- which(lengths > subset_length)
    rows <<- c(rows, ind) # WARNING: writing to variable outside apply() scope.
    substr(geohashes[ind], 1, subset_length)
  })))
  return(expanded[order(rows)])
}
