# Types --------------

#' Get Falling Fruit (FF) Types
#'
#' @export
#' @family Falling Fruit functions
#' @examples
#' types <- get_ff_types(pending = FALSE)
get_ff_types <- function(categories = c("forager", "freegan", "honeybee", "grafter"), uncategorized = TRUE, pending = TRUE, urls = TRUE, locale = "en") {

  # Pull json from API
  url <- parse_url("https://fallingfruit.org/api/0.2/types.json")
  query <- list(api_key = "BJBNKMWM", c = paste(intersect(Categories, categories), collapse = ","), uncategorized = ifelse(uncategorized, 1, 0), pending = ifelse(pending, 1, 0), locale = locale, urls = ifelse(urls, 1, 0))
  json <- content(GET(url, query = query))

  # Json to data.table
  json <- replace_values_in_list(json, NULL, NA)
  dt <- rbindlist(json, use.names = TRUE, fill = TRUE)
  dt[, order := .I]
  setkey(dt, id)

  # Numeric and named taxonomic ranks
  dt[, taxonomic_rank_order := taxonomic_rank]
  dt[, taxonomic_rank := Taxonomic_ranks[taxonomic_rank_order + 1]]

  # Vectorize and join synonyms with primary names
  dt[, common_names := list(list(na.remove(c(name, strsplit(synonyms, "[ ]*,[ ]*")[[1]])))), by = id]
  dt[, scientific_names := list(list(na.remove(c(scientific_name, strsplit(scientific_synonyms, "[ ]*,[ ]*")[[1]])))), by = id]

  # Format names (for matching and display)
  dt[, printed_common_names := lapply(common_names, format_strings, types = "printed_common_name")]
  dt[, matched_common_names := lapply(common_names, format_strings, types = "matched_common_name")]
  dt[, printed_scientific_names := lapply(scientific_names, format_strings, types = "printed_scientific_name")]
  dt[, matched_scientific_names := lapply(scientific_names, format_strings, types = "matched_scientific_name")]

  # Return types as data.table
  return(dt)
}

# Type Strings --------------

#' Build Type Strings
#'
#' @export
#' @family Falling Fruit functions
#' @examples
#' build_type_strings(1, "Apple")
#' build_type_strings(scientific_names = "Malus domestica")
#' build_type_strings(scientific_names = "Malus domestica", science_in = "()")
#' build_type_strings(c(1, 2), c("Apple", "Pear"), c("Malus domestica", "Pyrus communis"))
build_type_strings <- function(ids = NULL, common_names = NULL, scientific_names = NULL, science_in = "[]") {

  # Replace NA with blank strings
  ids[is.empty(ids)] <- ""
  common_names[is.empty(common_names)] <- ""
  scientific_names[is.empty(scientific_names)] <- ""

  # Build type strings
  type_strings <- clean_strings(paste0(ids, ": ", common_names, " ", substr(science_in, 1, 1), scientific_names, substr(science_in, 2, 2)))
  type_strings <- gsub("(:\\s*$)|(^: )|", "", type_strings)
  return(type_strings)
}

#' Parse Type Strings
#'
#' @export
#' @family Falling Fruit functions
#' @examples
#' type_strings <- build_type_strings(c(1, 2), c("Apple", "Pear"), c("Malus domestica", "Pyrus communis"))
#' str(parse_type_strings(type_strings))
parse_type_strings <- function(type_strings) {
  substrings <- str_match(type_strings, '^([0-9]+)?[:\\s]*([^\\[]+?)?[\\s]*(\\[(.+)\\])?$')
  return(Map(list, id = as.numeric(substrings[, 2]), name = substrings[, 3], scientific_name = substrings[, 5]))
}

#' Match Type Strings to Types
#'
#' @export
#' @family Falling Fruit functions
#' @examples
#' types <- get_ff_types()
#' match_type_strings("Apple", types)
#' match_type_strings(c("Apple [Malus domestica]", "Pear [Pyrus]"), types)
match_type_strings <- function(type_strings, types, simplify = FALSE) {
  ts <- parse_type_strings(type_strings)
  matches <- sapply(ts, function(t) {
    types[(id == t$id | is.na(t$id)) & (name == t$name | is.na(t$name)) & (scientific_name == t$scientific_name | is.na(t$scientific_name))]$id
  }, simplify = simplify)
  return(matches)
}

#' Normalize Type Strings
#'
#' @export
#' @family Falling Fruit functions
#' @examples
#' types <- get_ff_types()
#' type_strings <- c("Apple")
#' normalize_type_strings("Apple", types)
#' normalize_type_strings(c("14", "[Malus domestica]"), types)
normalize_type_strings <- function(type_strings, types) {

  # Verify type strings
  matched_type_strings <- na.omit(unique(unlist(strsplit(type_strings, "\\s*,\\s*"))))
  matches <- match_type_strings(matched_type_strings, types)
  n_matches <- sapply(matches, length)
  has_no_matches <- n_matches == 0
  has_many_matches <- n_matches > 1
  is_invalid <- has_no_matches | has_many_matches
  if (sum(has_no_matches) > 0) {
    cat("Unrecognized type strings:", sep = "\n")
    cat(matched_type_strings[has_no_matches], sep = "\n")
  }
  if (sum(has_many_matches) > 0) {
    cat("Ambiguous type strings:", sep = "\n")
    cat(paste(matched_type_strings[has_many_matches], "-> Matches", n_matches[has_many_matches], "types"), sep = "\n")
  }
  if (sum(is_invalid) > 0) {
    stop("Invalid type strings found.")
  }

  # Standardize type strings
  ids <- unlist(matches[n_matches == 1])
  old_strings <- paste0("(^|, )", quotemeta(matched_type_strings[n_matches == 1]), "($|,)")
  new_strings <- paste0("\\1", build_type_strings(ids, types[.(ids), name], types[.(ids), scientific_name]), "\\2")
  names(new_strings) <- old_strings
  return(str_replace_all(type_strings, new_strings))
}

# Locations --------------

#' Build Location Description
#'
#' Builds a description from its inputs:
#' [nx] type string, [yx] type string, ... + sep + notes (those unique and equal for all)
#'
#' WARNING: Not splitting at commas to support types with commas in them, so type_strings need to be single-type.
#'
#' @export
#' @family Falling Fruit functions
#' @examples
#' build_location_description(c("Apple", "Pear", "Pear"), notes = list(c("Planted 1999", "Height 10 m"), c("Planted 1999", "Height 20 m"), c("Planted 1999", "Height 30 m")))
build_location_description <- function(type_strings, notes = NULL, sep = ". ", frequency_in = "[]") {
  #frequencies <- summary(as.factor(unlist(strsplit(type_strings, "[ ]*,[ ]*"))))
  frequencies <- summary(as.factor(unlist(type_strings)))
  description <- paste0(substr(frequency_in, 1, 1), frequencies, "x", substr(frequency_in, 2, 2), " ", attr(frequencies, "names"), collapse = ", ")
  notes <- lapply(do.call(Map, c(base::c, notes)), unique_na)
  notes <- notes[!is.empty(notes)]
  if (length(notes) > 0) {
    description <- paste0(paste(description, paste(notes, collapse = sep), sep = sep), gsub("\\s*$", "", sep))
  }
  return(description)
}

# Categories --------------

#' Expand Binary Category Mask to Categories
#'
#' @export
#' @family Falling Fruit functions
#' @examples
#' expand_category_mask(0)
#' expand_category_mask(3)
expand_category_mask <- function(category_mask) {
  Categories[which(as.numeric(intToBits(category_mask)) == 1)]
}
