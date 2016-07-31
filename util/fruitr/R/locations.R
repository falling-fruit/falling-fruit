#' Load Locations Dataset
#'
#' TODO: Check that id field is unique, warn otherwise.
#'
#' @export
#' @family location import functions
read_locations <- function(file, latlng = c("lat", "lng"), id = "id", CRSobj = CRS("+proj=longlat +ellps=WGS84"), ...) {

  # Read file
  if (grepl("\\.csv", file)) {
    df <- read.csv(file, stringsAsFactors = FALSE, ...)
  } else if (grepl("\\.dbf", file)) {
    df <- read.dbf(file, as.is = TRUE)
  } else if (grepl("\\.shp", file)) {
    shp <- readOGR(file, layer = ogrListLayers(file)[1], ...)
    shp <- spTransform(shp, CRSobj)
    df <- shp@data
    ind <- sapply(df, is.factor)
    df[ind] <- lapply(df[ind], as.character)
    df$lng <- shp@coords[, 1]
    df$lat <- shp@coords[, 2]
  } else if (grepl("\\.kml", file)) {
    # get layer name from ogrinfo
    shp <- readOGR(file, "Features", ...)
    shp <- spTransform(shp, CRSobj)
    df <- shp@data
    ind <- sapply(df, is.factor)
    df[ind] <- lapply(df[ind], as.character)
    df$lng <- shp@coords[, 1]
    df$lat <- shp@coords[, 2]
  } else {
    df <- read.table(file, stringsAsFactors = FALSE, ...)
  }

  # Standardize lat,lng to "lat","lng"
  if (all(!is.empty(latlng), latlng %in% names(df))) {
    names(df)[names(df) == latlng[1]] = "lat"
    names(df)[names(df) == latlng[2]] = "lng"
  } else {
    warning('No coordinates available!')
  }

  # Standardize id to "id"
  if (all(!is.empty(id), id %in% names(df))) {
    names(df)[names(df) == id] = "id"
  } else {
    df$id <- 1:nrow(df)
  }

  # return
  return(data.table(df, key = "id"))
}

#' Match Against Falling Fruit Types
#'
#' TODO: Don't match if already matched.
#'
#' @export
#' @family location import functions
match_to_ff_types <- function(dt, types, saved_match_table) {

  # Initialize
  has_scientific_names <- "matched_scientific_name" %in% names(dt)
  has_common_names <- "matched_common_name" %in% names(dt)

  # Prepare names
  dt_name_fields <- intersect(c("matched_scientific_name", "matched_common_name", "printed_scientific_name", "printed_common_name"), names(dt))
  dt_name_combinations <- dt[, .(count = .N), by = dt_name_fields]
  setorderv(dt_name_combinations, dt_name_fields)
  if (has_scientific_names) {
    dt_names <- dt_name_combinations[, NA, by = matched_scientific_name][, V1 := NULL]
    setnames(dt_names, "matched_scientific_name", "name")
    type_names <- types[, .(name = unlist(matched_scientific_names)), by = id]
  } else {
    dt_names <- dt_name_combinations[, NA, by = matched_common_name][, V1 := NULL]
    setnames(dt_names, "matched_common_name", "name")
    type_names <- types[, .(name = unlist(matched_common_names)), by = id]
  }

  # Calculate string distances
  distance_matrix <- stringdistmatrix(dt_names$name, type_names$name)

  # Choose exact matches
  exact_matches <- apply(distance_matrix, 1, function(distances) {
    unique(type_names[distances == 0, id])
  })
  exact_match_strings <- sapply(exact_matches, function(type_ids) {
    sapply(type_ids, function(type_id) {
      types[id == type_id, build_type_strings(id, name, scientific_name)]
    })
  })

  # Choose fuzzy matches
  fuzzy_matches <- apply(distance_matrix, 1, function(distances) {
    are_nearby <- distances > 0 & distances < 3
    sorted_matches <- which(are_nearby)[order(distances[are_nearby])]
    head(unique(type_names[sorted_matches, id]), 2)
  })
  fuzzy_match_strings <- sapply(fuzzy_matches, function(type_ids) {
    sapply(type_ids, function(type_id) {
      types[id == type_id, build_type_strings(id, name, scientific_name)]
    })
  })

  # Compile and clean up results
  dt_names[, types := sapply(exact_match_strings, function(strings) { ifelse(length(strings) == 1, strings, NA) })]
  dt_names[, fuzzy_matches := sapply(fuzzy_match_strings, paste, collapse = ", ")]
  dt_names[, exact_matches := sapply(exact_match_strings, function(strings) { ifelse(length(strings) < 2, NA, paste(strings, collapse = ", ")) })]
  dt_names[, unverified := as.character(NA)]
  match_table <- merge(dt_name_combinations, dt_names, by.x = ifelse(has_scientific_names, "matched_scientific_name", "matched_common_name"), by.y = "name")
  # TODO: Leave as printed_* (and update following code accordingly) ?
  if (has_scientific_names) {
    setnames(match_table, "printed_scientific_name", "scientific_name")
    match_table[, matched_scientific_name := NULL]
  }
  if (has_common_names) {
    setnames(match_table, "printed_common_name", "common_name")
    match_table[, matched_common_name := NULL]
  }
  match_table[!is.na(exact_matches) | !is.na(types), fuzzy_matches := NA]
  setcolorder(match_table, c("count", ifelse(has_common_names, "common_name", NA), ifelse(has_scientific_names, "scientific_name", NA), "types", "fuzzy_matches", "exact_matches", "unverified"))

  # Update and save results
  if (is.null(saved_match_table)) {
    return(match_table)
  } else {
    saved_match_table$types <- ifelse(is.na(saved_match_table$types) | saved_match_table$types == "", match_table$types, saved_match_table$types)
    saved_match_table$exact_matches <- ifelse(is.na(saved_match_table$exact_matches) | saved_match_table$exact_matches == "", match_table$exact_matches, saved_match_table$exact_matches)
    saved_match_table$fuzzy_matches <- ifelse(is.na(saved_match_table$fuzzy_matches) | saved_match_table$fuzzy_matches == "", match_table$fuzzy_matches, saved_match_table$fuzzy_matches)
    saved_match_table$unverified <- ifelse(is.na(saved_match_table$unverified) | saved_match_table$unverified == "", match_table$unverified, saved_match_table$unverified)
    return(saved_match_table)
  }
}

#' Apply Type Matches
#'
#' @export
#' @family location import functions
apply_ff_type_matches <- function(dt, types, match_table, drop = FALSE) {

  # Verify completeness
  is_empty <- sapply(match_table$types, is.empty)
  if (sum(is_empty) > 0) {
    cat("Empty match_table rows:", sep = "\n")
    cat(build_type_strings(common_names = match_table$common_name[is_empty], scientific_names = match_table$scientific_name[is_empty]), sep = "\n")
    if (!drop) {
      stop("Use drop = TRUE to ignore and drop corresponding dt rows.")
    }
  }

  # Standardize assigned types
  # TODO: Avoid unfortunate scoping?
  e <- environment()
  match_table[, types := normalize_type_strings(types, e$types)]

  # Prepare row assignments
  dt <- merge(dt, match_table[, intersect(c("scientific_name", "common_name", "types", "unverified"), names(match_table)), with = FALSE], by.x = intersect(c("printed_scientific_name", "printed_common_name"), names(dt)), by.y = intersect(c("scientific_name", "common_name"), names(match_table)))

  # Drop unassigned rows
  if (drop) {
    unassigned <- is.na(dt$types) | dt$types == "NA"
    if (sum(unassigned) > 0) {
      cat(paste("Dropping", sum(unassigned), "unassigned dt row(s)."), sep = "\n")
      dt <- dt[!unassigned]
    }
  }
  return(dt)
}

#' Aggregate Locations by Position
#' TODO: Make faster?
#' WARNING: build_location_description expects singular type strings.
#' @export
aggregate_locations_by_position <- function(dt, sep = ". ") {
  # Select position fields
  if (all(c("lat", "lng") %in% names(dt))) {
    position_fields <- c("lat", "lng")
  } else if ("address" %in% names(dt)) {
    position_fields <- "address"
  } else {
    stop("No position fields found (lat,lng | address).")
  }

  # Apply default description field
  if (!("description" %in% names(dt))) {
    printed_common_names <- dt$printed_common_name
    printed_scientific_names <- dt$printed_scientific_name
    science_in_string <- "()"
    if (is.null(printed_common_names)) {
      science_in_string <- ""
    }
    dt[, description := build_type_strings(common_names = printed_common_names, scientific_names = printed_scientific_names, science_in = science_in_string)]
  }

  # Add missing fields
  if (!("notes" %in% names(dt))) {
    dt[, notes := Map(list, NA)]
  }
  if (!("author" %in% names(dt))) {
    dt[, author := NA]
  }
  if (!("access" %in% names(dt))) {
    dt[, access := NA]
  }

  # Convert id to character (for ifelse/paste in next step)
  if (!is.character(dt$id)) {
    dt[, id := as.character(id)]
  }

  # Aggregate by duplicated positions
  # (Multi-type locations should be split apart before being joined together here)
  fdt <- dt[, .(
    ids = ifelse(.N == 1, id, paste(unique(id), collapse = ", ")),
    types = ifelse(.N == 1, types, paste(unique(types), collapse = ", ")),
    description = build_location_description(description, notes, sep = sep),
    access = ifelse(.N == 1, access, unique_na(access)),
    author = ifelse(.N == 1, author, paste(unique(author), collapse = ", "))
  ), by = position_fields]
  return(fdt)
}

#' Write Locations to File for Import
#'
#' See http://fallingfruit.org/locations/import for format.
#' FIXME: Do not edit dt in place.
#'
#' @export
#' @family location import functions
write_locations_for_import <- function(dt, file, drop_extra_fields = TRUE) {

  # Initialize
  Location_import_fields <- c('Ids','Types','Description','Lat','Lng','Address','Season Start','Season Stop','No Season','Access','Unverified','Yield Rating','Quality Rating','Author','Photo URL')
  setnames(dt, capitalize_words(gsub("\\.|_", " ", names(dt))))
  extra_fields <- setdiff(names(dt), Location_import_fields)
  missing_fields <- setdiff(Location_import_fields, names(dt))

  # Format columns
  if (length(missing_fields) > 0) {
    dt[, (missing_fields) := NA]
  }
  setcolorder(dt, c(Location_import_fields, extra_fields))
  if (drop_extra_fields & length(extra_fields) > 0) {
    dt[, (extra_fields) := NULL]
  }

  # Write result to file
  write.csv(dt, file, na = "", row.names = FALSE)
}
