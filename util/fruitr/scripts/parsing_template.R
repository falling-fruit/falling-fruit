source('api_functions.r')
source('parsing_functions.r')

#############
## Initialize

## Load data
directory <- "DIRECTORY"
file <- "FILE"
#readLines(paste0(directory, file), n = 1)
dt <- load_data(paste0(directory, file), latlng = c("LATITUDE", "LONGITUDE"), id = NULL)

#############
## Prepare names

dt$common_name <- dt$COMMON
dt$scientific_name <- dt$SCIENTIFIC

if ("common_name" %in% names(dt)) {
  dt[, printed_common_name := format_strings(common_name, "printed_common_name")]
  dt[, matched_common_name := format_strings(common_name, "matched_common_name")]
}

if ("scientific_name" %in% names(dt)) {
  dt[, printed_scientific_name := format_strings(scientific_name, "printed_scientific_name")]
  dt[, matched_scientific_name := format_strings(scientific_name, "matched_scientific_name")]
}

matched_name_fields <- intersect(c("matched_scientific_name", "matched_common_name"), names(dt))
print(dt[order(dt[, matched_name_fields[1], with = FALSE]), matched_name_fields, with = FALSE][, .(count = .N), by = matched_name_fields], nrows = Inf)

#############
## Match names to types
match_table <- NULL

# Perform match
types <- get_ff_types(locale = "en")
match_table <- match_to_ff_types(dt, types, match_table)

# Edit matches
match_table <- as.data.table(fix(match_table)); match_table$types <- normalize_type_strings(match_table$types, types)

# Save to file
write.csv(match_table, paste0(directory, gsub("(\\..*)*$", "-match_table.csv", file)), row.names = TRUE, na = "")

####
## Apply matches
#types <- get_ff_types(locale = "en")
#match_table <- as.data.table(read.csv(paste0(directory, gsub("(\\..*)*$", "-match_table.csv", file)), stringsAsFactors = FALSE, row.names = 1, na.strings = ""))
dt <- apply_ff_type_matches(dt, types, match_table, drop = FALSE)

####
## Format fields

# Notes
dt[, notes := Map(list, NA)]

# Author
dt[, author := "AUTHOR"]

# Access
dt[, access := NA]

# Address
dt[, address := NA]

####
## Aggregate overlapping locations
fdt <- aggregate_locations_by_position(dt, sep = ". ")

####
## Export
out_file <- paste0(directory, gsub("(\\..*)*$", "-FINAL.csv", file))
write_locations_for_import(fdt, out_file, drop_extra_fields = TRUE)
