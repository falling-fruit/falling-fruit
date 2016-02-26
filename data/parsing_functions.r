####
## Load libraries
library(data.table) # fast data.frame
library(stringdist) # fuzzy matching

####
## FUNCTIONS

## Load external dataset
load_data <- function(file, latlng = c("lat", "lng"), id = "id") {
  
  # Read file
  if (grepl("\\.csv", file)) {
    df <- read.csv(file, stringsAsFactors = FALSE)
  } else if (grepl("\\.dbf", file)) {
    library(foreign)
    df <- read.dbf(file, as.is = TRUE)
  } else if (grepl("\\.shp", file)) {
    library(rgdal)
    shp <- readOGR(file, layer = ogrListLayers(file)[1])
    shp <- spTransform(shp, CRS("+proj=longlat +ellps=WGS84"))
    df <- shp@data
    ind <- sapply(df, is.factor)
    df[ind] <- lapply(df[ind], as.character)
    df$lng <- shp@coords[, 1]
    df$lat <- shp@coords[, 2]
  } else if (grepl("\\.kml", file)) {
    # get layer name from ogrinfo
    shp <- readOGR(file, "Features")
    shp <- spTransform(shp, CRS("+proj=longlat +ellps=WGS84"))
    df <- shp@data
    ind <- sapply(df, is.factor)
    df[ind] <- lapply(df[ind], as.character)
    df$lng <- shp@coords[, 1]
    df$lat <- shp@coords[, 2]
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

## Load types
# TODO: Add language support
load_types = function(categories = c("forager", "freegan", "honeybee", "grafter"), uncategorized = TRUE, pending = FALSE, locale = "en", urls = FALSE) {
  types <- get_ff_types(categories = categories, uncategorized = uncategorized, pending = pending, locale = locale, urls = urls)
  types <- data.table(types, key = "id")
  common_names <- types[, list(list(c(name, strsplit(synonyms, "[ ]*,[ ]*")[[1]], na.rm = TRUE))), by = id][[2]]
  scientific_names <- types[, list(list(c(scientific_name, strsplit(scientific_synonyms, "[ ]*,[ ]*")[[1]], na.rm = TRUE))), by = id][[2]]
  types$printed_common_names <- sapply(common_names, format_strings, types = "printed_common_name")
  types$matched_common_names <- sapply(common_names, format_strings, types = "matched_common_name")
  types$printed_scientific_names <- sapply(scientific_names, format_strings, types = "printed_scientific_name")
  types$matched_scientific_names <- sapply(scientific_names, format_strings, types = "matched_scientific_name")
  return(types)
}

####
## Format

## Capitalize first letter of each word. 
# Skips numbers at start of words (e.g. 3-in-1 pear).
capitalize_words <- function(x, strict = FALSE, first = FALSE) {
  if (strict) {
    x <- tolower(x)
  }
	if (first) {
	  x <- gsub("^([^\\p{L}0-9]*)(\\p{L})", "\\1\\U\\2", x, perl = TRUE)
	} else {
	  x <- gsub("(^|\\s)([^\\s\\p{L}0-9]*)(\\p{L})", "\\1\\2\\U\\3", x, perl = TRUE)
	}
	return(x)
}

## Clean up messy strings
clean_strings <- function(x) {
  start_x <- x
  
  # Non-empty substitutions
  x <- gsub("`|\\\"", "'", x, perl = TRUE)  # quotes -> '
  x <- gsub("\\s*(\\s*\\.+)+", ".", x, perl = TRUE)  # remove duplicate periods
  x <- gsub("(\\s*,+\\s*)+", ",", x, perl = TRUE)  # remove duplicate commas
  x <- gsub("([\\s,]*\\.+(\\s*,+)*)+", ".", x, perl = TRUE)  # merge punctuation
  x <- gsub("(\\s)+", " ", x, perl = TRUE)  # squish white space
  
  # Empty substitutions
  remove <- paste(
    "\\(\\s*\\)|\\[\\s*\\]", # empty parentheses and brackets
    "'(\\s*'*\\s*)'", # empty quotes
    "^\\s+|\\s+$|\\s+(?=[\\.|,])", # trailing white space
    "^[,\\.\\s]+|[\\s,]+$", # leading punctuation, trailing commas
    sep = "|")
  x <- gsub(remove, "", x, perl = TRUE)
  
  # Iterate
  if (all(x == start_x)) {
    return(x)
  } else {
    clean_strings(x)
  }
}

# Format specialty string fields (scientific name, address)
format_strings <- function(x, types = "", clean = TRUE) {
  start_x <- x
  if (clean) {
    x <- clean_strings(x)
  }
  if ("address" %in% types) {
    x <- capitalize_words(x, strict = TRUE)	# force lowercase, then capitalize each word
    x <- gsub("\\.", "", x)	# remove periods
    x <- gsub("(se|sw|ne|nw)( |$)", "\\U\\1\\2", x, perl = TRUE, ignore.case = TRUE)	# capitalize SE, SW, NE, NW
    x <- gsub("Mc([a-z])", "Mc\\U\\1", x, perl = TRUE, ignore.case = TRUE)	# restore McCaps
    x <- gsub("Av( |$)", "Ave\\1", x, ignore.case = TRUE)	# Av -> Ave
  }
  if ("printed_common_name" %in% types) {
    x <- capitalize_words(x, strict = TRUE, first = TRUE) # force lowercase, then capitalize first word
  }
  if ("matched_common_name" %in% types) {
    x <- tolower(x)
    x <- gsub("\\s*\\(.*\\)(\\s|$)", "\\1", x) # remove disambiguation "(category)"
  }
  if ("printed_scientific_name" %in% types) {
    x <- capitalize_words(x, strict = TRUE, first = TRUE) # force lowercase, then capitalize first word
    x <- gsub("'([a-z])([a-z])", "'\\U\\1\\L\\2", x, perl = TRUE)  # capitalize letter proceeding ' if followed by letter
    x <- gsub("(subsp|var|subvar|f|subf)( |$)", "\\1.\\2", x) # add . to infraspecific abbreviations
    x <- gsub(" (species|spp|ssp|sp)( |$)", " sp.\\1", x, ignore.case = TRUE) # species -> sp
    x <- gsub("(^[a-z]+$)", "\\1 sp.", x, ignore.case = TRUE) # Genus -> add sp FIXME: What if higher taxonomy?
    x <- gsub("([ ]+[a-z×][ ]+)", "\\L\\1", x, ignore.case = TRUE, perl = TRUE) # standardize hybrid x (Genus x species)
  }
  if ("matched_scientific_name" %in% types) {
    x <- tolower(x)
    x <- gsub(" (species|spp|ssp|sp)( |$)", "\\2", x) # remove species
    x <- gsub(" (subsp\\.*|var\\.*|subvar\\.*|f\\.*|subf\\.*)( |$)", "\\2", x) # remove infraspecific abbreviations
    x <- gsub("([ ]+[a-z×][ ]+)", " ", x) # remove hybrid x
    x <- gsub("'.*'", "", x) # remove quotes (around variety names)
  }
  if (all(x == start_x)) {
    return(x)
  } else {
    format_strings(x, types = types, clean = clean)
  }
}

####
## Export
# see: http://fallingfruit.org/locations/import

export_data <- function(dt, file, drop_extra_fields = TRUE) {
  
  # Initialize
  template_fields <- c('Id','Type','Description','Lat','Lng','Address','Season Start','Season Stop','No Season','Access','Unverified','Yield Rating','Quality Rating','Author','Photo URL')
  setnames(dt, capitalize_words(gsub("\\.|_", " ", names(dt))))
  extra_fields <- setdiff(names(dt), template_fields) 
	missing_fields <- setdiff(template_fields, names(dt))
  
  # Copy data.table and format columns
  dt <- copy(dt)
  if (length(missing_fields) > 0) {
    dt[, (missing_fields) := NA] 
  }
  setcolorder(dt, c(template_fields, extra_fields))
	if (drop_extra_fields & length(extra_fields) > 0) {
	  dt[, (extra_fields) := NULL]
	}
  
  # Write result to file
	write.csv(dt, file, na = "", row.names = FALSE)
}

##########
## Helper functions

is.empty <- function(x) {
  if (!exists(as.character(substitute(x)))) {
    return(TRUE)
  }
  if (any(is.null(x), length(x) == 0, nrow(x) == 0)) {
    return(TRUE)
  }
  results <- sapply(x, function(x_i) {
    suppressWarnings(any(
      is.null(x_i), 
      length(x_i) == 0, 
      nrow(x_i) == 0, 
      is.na(x_i), 
      all(is.character(x_i) == 1 && x_i == "")
    ))
  })
  return(as.vector(results))
}

# Extend c()
c <- function(..., na.rm = FALSE) {
  x <- base::c(...)
  if (na.rm) {
    x <- x[!is.na(x)]
  }
  return(x)
}

build_type_strings <- function(ids = NULL, common_names = NULL, scientific_names = NULL, science_in = "[]") {
  type_strings <- clean_strings(paste0(ids, ": ", common_names, " ", substr(science_in, 1, 1), scientific_names, substr(science_in, 2, 2)))
  type_strings <- gsub("(:\\s*$)|(^: )", "", type_strings)
  return(type_strings)
}

# [nx] type string, [yx] type string, ... + sep + note
build_description <- function(type_strings, note = NULL, sep = ". ", frequency_in = "[]") {
  frequencies <- summary(as.factor(type_strings))
  description <- paste0(substr(frequency_in, 1, 1), frequencies, "x", substr(frequency_in, 2, 2), " ", attr(frequencies, "names"), collapse = ", ")
  if (!is.empty(note)) {
    description <- paste0(description, sep, note)
  }
  return(description)
}

# Return single unique, or NA
unique_na <- function(x) {
  ux <- unique(x)
  if (length(ux) == 1) {
    return(ux)
  } else {
    return(as(NA, class(x)))
  }
}

# Convert Swiss Projection CH1903 (E, N) to WGS84 (lat, lng)
# http://www.swisstopo.admin.ch/internet/swisstopo/de/home/topics/survey/sys/refsys/switzerland.parsysrelated1.24280.downloadList.87003.DownloadFile.tmp/ch1903wgs84de.pdf (but switch x and y)
ch1903.to.wgs84 = function(X) {
  x <- (X[, 1] - 6e5) / 1e6
  y <- (X[, 2] - 2e5) / 1e6
  lng <- (2.6779094 + 4.728982 * x + 0.791484 * x * y + 0.1306 * x * y^2 - 0.0436 * x^3) * (100 / 36)
  lat <- (16.9023892 + 3.238272 * y - 0.270978 * x^2 - 0.002528 * y^2 - 0.0447 * x^2 * y - 0.014 * y^3) * (100 / 36)
  return(cbind(lng, lat))
}