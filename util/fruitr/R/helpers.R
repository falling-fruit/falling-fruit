# Object Manipulation --------------

#' Replace Values in List
#'
#' @export
#' @family helper functions
#' @examples
#' x <- list(NULL, list(NULL, NA))
#' str(replace_values_in_list(x, NULL, 1))
#' str(replace_values_in_list(x, list(NULL, NA), 1))
#' str(replace_values_in_list(x, list(NULL, NA), list(1, 2)))
replace_values_in_list <- function(x, old, new) {
  if (!is.list(old) || (is.list(old) && length(old) == 0)) {
    if (length(old) > 1) old <- as.list(old)
    else old <- list(old)
  }
  if (!is.list(new) || (is.list(new) && length(new) == 0)) {
    if (length(new) > 1) new <- as.list(new)
    else new <- list(new)
  }
  new <- rep_len(new, length(old))
  for (i in seq_along(old)) {
    x <- lapply(x, function(x_i) {
      if (identical(x_i, old[[i]])) {
        new[[i]]
      } else if (is.list(x_i) && length(x_i) > 0) {
        replace_values_in_list(x_i, old[[i]], new[[i]])
      } else {
        x_i
      }
    })
  }
  return(x)
}

#' Remove Missing Values from Object
#'
#' @export
#' @family helper functions
na.remove <- function(x, ...) {
  y <- na.omit(x, ...)
  attributes(y) <- NULL
  return(y)
}

#' Expand List by Split
#'
#' NOTE: Currently unused.
#'
#' @export
#' @family helper functions
#' @examples
#' x <- list(list(count = 1, label = "a, b"), list(count = 2, label = "c"))
#' str(expand_list_by_split(x, "label"))
expand_list_by_split <- function(x, name, split = "\\s*,\\s*") {
  splits <- lapply(x, function(x_i) {
    if (is.null(x_i[[name]])) {
      return(NA)
    } else {
      return(strsplit(as.character(x_i[[name]]), split)[[1]])
    }
  })
  n_splits <- sapply(splits, FUN = length)
  x.rep <- x[rep(seq(length(x)), n_splits)]
  splits.all <- unlist(splits)
  for (i in 1:length(x.rep)) {
    if (is.na(splits.all[i])) next
    x.rep[[i]][[name]] <- splits.all[i]
  }
  return(x.rep)
}

#' Check if Object is Empty
#'
#' FIXME: Returns FALSE if object doesn't exist when called within other function.
#'
#' @export
#' @family helper functions
#' @examples
#' is.empty(list())
#' is.empty(list(NULL, NA, "", c()))
#' is.empty(list(1, NULL, NA, "", c()))
is.empty <- function(x, env = globalenv()) {
  if (missing(x)) {
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
      all(is.na(x_i)),
      all(is.character(x_i) == 1 && x_i == "")
    ))
  })
  return(as.vector(results))
}

#' Return Single Unique Value or NA
#'
#' @export
#' @family helper functions
#' @examples
#' unique_na(c(1, 1))
#' unique_na(c(1, 2))
#' unique_na(c(1, NA), na.rm = FALSE)
#' unique_na(c(1, NA), na.rm = TRUE)
unique_na <- function(x, na.rm = FALSE) {
  if (na.rm) {
    x <- x[!is.na(x)]
  }
  ux <- unique(x)
  if (length(ux) == 1) {
    return(ux)
  } else {
    return(as(NA, class(x)))
  }
}

#' Melt Data Table by List Column
#'
#' @export
#' @family helper functions
#' @examples
#' dt <- data.table(label = list(list("a", "b"), list("c")), count = c(1, 2))
#' melt_by_listcol(dt, "label")
#' melt_by_listcol(dt, 1)
melt_by_listcol <- function(dt, column) {
  values <- dt[, column, with = FALSE][[1]]
  n <- sapply(values, length)
  return(dt[rep(1:nrow(dt), n)][, c(column) := unlist(values)][])
}

# String Formatting --------------

#' Quote Metacharacters
quotemeta <- function(string) {
  stringr::str_replace_all(string, "(\\W)", "\\\\\\1")
}

#' Capitalize Words
#' Skips numbers at start of words (e.g. 3-in-1 pear).
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

#' Clean Strings
#'
#' Performs general string cleaning operations.
#'
#' @family helper functions
#' @export
#' @examples
#' clean_strings(" ..[] Hello,,  `world`.. how are you?() ")
clean_strings <- function(x) {
  start_x <- x

  # Non-empty substitutions
  x <- gsub("`|\\\"", "'", x, perl = TRUE)  # quotes -> '
  x <- gsub("\\s*(\\s*\\.+)+", ".", x, perl = TRUE)  # remove duplicate periods
  x <- gsub("\\s*(\\s*,+)+", ",", x, perl = TRUE)  # remove duplicate commas
  x <- gsub("([\\s,]*\\.+(\\s*,+)*)+", ".", x, perl = TRUE)  # merge punctuation
  x <- gsub("(\\s)+", " ", x, perl = TRUE)  # squish white space

  # Empty substitutions
  remove <- paste(
    "(?:^|\\s*)NA(?:$|\\s*)", # NAs in string
    "\\(\\s*\\)|\\[\\s*\\]", # empty parentheses and brackets
    "'(\\s*'*\\s*)'", # empty quotes
    "^\\s+|\\s+$|\\s+(?=[\\.|,])", # trailing white space
    "^[,\\.\\s]+|[\\s,]+$", # leading punctuation, trailing commas
    "^[\\-]+|[\\-]+$", # trailing dashes
    sep = "|")
  x <- gsub(remove, "", x, perl = TRUE)

  # Iterate
  changed <- x != start_x
  changed[is.na(changed)] <- FALSE
  if (any(changed)) {
    x[changed] <- clean_strings(x[changed])
  }
  return(x)
}

#' Format Specialty Strings
#'
#' Supports species common names, latin names, and addresses.
#'
#' @family helper functions
#' @export
#' @examples
#' format_strings(" 123 SE. MCDONALD AV ", types = "address")
#' format_strings("Malus X Domestica Subsp gala 'gala'", types = "printed_scientific_name")
#' format_strings("Malus X Domestica Subsp gala 'gala'", types = "matched_scientific_name")
#' format_strings("Tamarix rubella Batt.", types = "printed_scientific_name")
#' format_strings("Tamarix lucronensis Sennen & Elias", types = "printed_scientific_name")
#' format_strings("Tamarix laxa var. subspicata Ehrenb.", types = "printed_scientific_name")
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
    # TODO: Remove following?
    x <- gsub("\\s*\\(.*\\)(\\s|$)", "\\1", x) # remove disambiguation "(category)"
  }
  if (any(c("printed_scientific_name", "matched_scientific_name") %in% types)) {
    x <- gsub("\\s*\\([^\\)]*\\)|,.*$", "", x) # clear parentheses or after first comma
    x <- gsub("^([A-Z].*?)\\s([A-Z].*)", "\\1", x, perl = TRUE)  # clear after second capital letter (if preceded by space)
    x <- gsub("(auct.|auctt.)+\\s(nec|non|mult.)*", "", x, perl = TRUE) # clear auctorum notation
  }
  if ("printed_scientific_name" %in% types) {
    x <- capitalize_words(x, strict = TRUE, first = TRUE) # force lowercase, then capitalize first word
    x <- gsub("'([a-z])([a-z])", "'\\U\\1\\L\\2", x, perl = TRUE)  # capitalize letter proceeding ' if followed by letter
    x <- gsub("(subsp|var|subvar|f|subf|subg)( |$)", "\\1.\\2", x) # add . to infraspecific abbreviations
    x <- gsub(" (species|spp|ssp|sp)( |$)", " sp.\\1", x, ignore.case = TRUE) # species -> sp
    x <- gsub("(^[a-z]+$)", "\\1 sp.", x, ignore.case = TRUE) # Genus -> add sp FIXME: What if higher taxonomy?
    x <- gsub("([ ]+[a-z×][ ]+)", "\\L\\1", x, ignore.case = TRUE, perl = TRUE) # standardize hybrid x (Genus x species)
  }
  if ("matched_scientific_name" %in% types) {
    x <- tolower(x)
    x <- gsub(" (species|spp|ssp|sp|subsp|var|subvar|f|subf|subg)(\\.*)( |$)", "\\3", x) # remove (infra)species abbreviations
    x <- gsub("([ ]+[a-z×][ ]+)", " ", x) # remove hybrid x
    x <- gsub("'.*'", "", x) # remove quotes (around variety names)
  }
  # Iterate
  changed <- x != start_x
  changed[is.na(changed)] <- FALSE
  if (any(changed)) {
    x[changed] <- format_strings(x[changed], types = types, clean = clean)
  }
  return(x)
}

unescape_html <- function(str){
  xml2::xml_text(xml2::read_html(paste0("<x>", str, "</x>")))
}

# Translations --------------

#' Normalize Language
#'
#' Returns the highest level ISO or Wikipedia language code corresponding to the ISO or Wikipedia language code, language name, or autonym provided. If the input matches zero or multiple entries, the input is returned and a warning is raised.
#'
#' @family helper functions
#' @export
#' @examples
#' normalize_language("spa")
#' normalize_language("Spanish")
#' normalize_language("Español")
#' normalize_language("Espagnol")
normalize_language = function(x, types = c("locale", "variant", "ISO639.1", "ISO639.2T", "ISO639.2B", "ISO639.3", "ISO639.6", "wikipedia", "other", "autonym", "en", "fr", "de", "ru", "es", "it", "zh")) {

  # Prepare input
  if (is.empty(x)) {
    return(NA_character_)
  }
  x <- tolower(x)
  cols <- intersect(types, names(Language_codes))

  # Prioritize code (over name) column matches if both selected
  code_cols <- c("locale", "variant", "ISO639.1", "ISO639.2T", "ISO639.2B", "ISO639.3", "ISO639.6", "wikipedia", "other")
  selected_code_cols <- intersect(cols, code_cols)
  selected_name_cols <- setdiff(cols, code_cols)
  if (length(selected_code_cols) > 0 && length(selected_name_cols) > 0) {
    n_matching_codes <- sum(sapply(selected_code_cols, function(code) {
      any(!is.na(Language_codes[[code]]) & grepl(paste0("(^|,\\s*)", quotemeta(x), "($|,)"), Language_codes[[code]]))
    }))
    if (n_matching_codes > 0) {
      cols <- selected_code_cols
    } else {
      cols <- selected_name_cols
    }
  }

  # Search and filter results
  ind <- unique(unlist(sapply(cols, function(col) {
    which(grepl(paste0("(^|,\\s*)", quotemeta(x), "($|,)"), Language_codes[[col]]))
  })))
  # # Return full result?
  # return(apply(Language_codes[ind], 1, as.list))
  if (length(ind) == 0) {
    warning(paste0("[", x, "] Language not recognized"))
    return(NA_character_)
  } else if (length(ind) > 1) {
    warning(paste0("[", x, "] Language found multiple times"))
    return(NA_character_)
  } else {
    codes <- as.character(Language_codes[ind, code_cols, with = FALSE])
    if (all(is.empty(codes))) {
      warning(paste0("[", x, "] Language does not have a supported code"))
      return(x)
    } else {
      return(codes[which(!is.na(codes))[1]])
    }
  }
}

#' Subset Search Results
#'
#' Difference search results based on subsetting of search strings (interpreted as search phrases).
#'
#' @family helper functions
#' @export
#' @examples
#' # Pine: 20, Blue pine: 17
#' strings <- c("Pine", "Blue pine")
#' results <- c(20, 17)
#' subset_search_results(strings, results) # 3, 17
#' # Pine: 20, Blue pine: 17, White blue pine: 10, White: 20
#' strings <- c("Pine", "Blue pine", "White blue pine", "White")
#' results <- c(20, 17, 10, 20)
#' subset_search_results(strings, results) # 3, 7, 10, 10
#' # Pine: 20, Blue pine: 17, Blue pine a: 10, Blue pine b: 5, Blue pine b c: 1
#' strings <- c("Pine", "Blue pine", "Blue pine a", "Blue pine b", "Blue pine b c")
#' results <- c(20, 17, 10, 5, 1)
#' subset_search_results(strings, results) # 3, 2, 10, 4, 1
#' # Pine: 20, Blue: 15, Blue pine: 10, Pine blue: 3
#' strings <- c("Pine", "Blue", "Blue pine", "Pine blue")
#' results <- c(20, 15, 10, 3)
#' subset_search_results(strings, results) # 7, 2, 10, 3
#' # Pine: 200, Blue pine: 100, White pine: 100
subset_search_results <- function(strings, values, ignore.case = TRUE) {
  subsets <- do.call("rbind", lapply(paste0(strings, " | ", strings), grepl, x = strings, ignore.case = ignore.case))
  # Proceed in order of least to most children, most to least parents
  n_children <- rowSums(subsets)
  n_parents <- colSums(subsets)
  node_sequence <- seq_len(length(strings))[order(n_children, -n_parents)]
  for (node in node_sequence) {
    # skip leaf nodes (children == 0)
    if (n_children[node] > 0) {
      is_child <- subsets[node, ]
      is_direct_child <- is_child & n_parents == min(n_parents[is_child])
      values[node] <- values[node] - sum(values[is_child])
      #values[node] <- values[node] - max(values[is_direct_child]) - sum(values[is_child & !is_direct_child])
    }
  }
  return(values)
}

# Datum Conversions --------------

#' Convert Swiss Projection CH1903 (E, N) to WGS84 (lng, lat)
#'
#' See http://www.swisstopo.admin.ch/internet/swisstopo/de/home/topics/survey/sys/refsys/switzerland.parsysrelated1.24280.downloadList.87003.DownloadFile.tmp/ch1903wgs84de.pdf (but switch x and y)
#'
#' @family helper functions
#' @export
#' @examples
#' ch1903_to_wgs84(0, 1000)
ch1903_to_wgs84 <- function(x, y = NULL) {
  if (is.null(y)) {
    X <- as.matrix(x)
  } else {
    X <- as.matrix(cbind(x, y))
  }
  x <- (X[, 1] - 6e5) / 1e6
  y <- (X[, 2] - 2e5) / 1e6
  lng <- (2.6779094 + 4.728982 * x + 0.791484 * x * y + 0.1306 * x * y^2 - 0.0436 * x^3) * (100 / 36)
  lat <- (16.9023892 + 3.238272 * y - 0.270978 * x^2 - 0.002528 * y^2 - 0.0447 * x^2 * y - 0.014 * y^3) * (100 / 36)
  return(cbind(lng, lat))
}
