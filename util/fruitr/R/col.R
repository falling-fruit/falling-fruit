#' Get Catalogue of Life (COL) Search Results
#'
#' See documentation at \url{http://webservice.catalogueoflife.org/col/webservice}.
#'
#' @family COL functions
#' @export
#' @examples
#' str(content(get_col_search("Malus domestica")))
#' str(content(get_col_search("Abelmoschus")))
#' str(content(get_col_search("Prunus")))
get_col_search <- function(name, format = "json", response = "terse", start = 0) {
  url <- parse_url("http://www.catalogueoflife.org/col/webservice")
  query <- mget(c("name", "format", "response", "start"))
  return(GET(url, query = query[sapply(query, "!=", "")]))
}

#' Parse Catalogue of Life (COL) Search Results
#'
#' @family COL functions
#' @export
#' @examples
#' s <- get_col_search("Malus domestica")
#' str(parse_col_search(s))
#' str(parse_col_search(s, accepted_name = FALSE))
#' str(parse_col_search(s, exact = FALSE))
#' s <- get_col_search("Apple")
#' str(parse_col_search(s, scientific_name = FALSE))
parse_col_search <- function(search, types = c("results", "ids"), exact = TRUE, scientific_name = TRUE, accepted_name = TRUE, ignore.case = TRUE) {
  result <- list()
  json <- content(search)
  name <- json$name
  ## Filter results
  if (exact) {
    name <- paste0("^", name, "$")
  }
  is_match <- grepl(name, sapply(json$results, "[[", "name"), ignore.case = ignore.case)
  name_status <- sapply(json$results, "[[", "name_status")
  is_common_name <- name_status == "common name"
  if (scientific_name) {
    ind <- is_match & !is_common_name
    # is_accepted <- name_status == "accepted name"
  } else {
    ind <- is_match & is_common_name
  }
  if (accepted_name) {
    json$results <- lapply(json$results[ind], function(result) {
      if (!is.null(result$accepted_name)) {
        return(result$accepted_name)
      } else {
        return(result)
      }
    })
  } else {
    json$results <- json$results[ind]
  }
  ## Results
  if ("results" %in% types) {
    result$results <- json$results
  }
  ## IDs
  if ("ids" %in% types) {
    result$ids <- sapply(json$results, "[[", "id")
  }
  ## Return
  return(result)
}

#' Get Catalogue of Life (COL) Page
#'
#' See documentation at \url{http://webservice.catalogueoflife.org/col/webservice}.
#'
#' @family COL functions
#' @export
#' @examples
#' s <- get_col_search("Malus domestica")
#' id <- parse_col_search(s, "ids")$ids[1]
#' str(content(get_col_page(id)))
get_col_page <- function(id, format = "json", response = "full") {
  url <- parse_url("http://www.catalogueoflife.org/col/webservice")
  query <- mget(c("id", "format", "response"))
  return(GET(url, query = query[sapply(query, "!=", "")]))
}

#' Parse Catalogue of Life (COL) Page
#'
#' @family COL functions
#' @export
#' @examples
#' s <- get_col_search("Malus domestica")
#' id <- parse_col_search(s, "ids")$ids[1]
#' pg <- get_col_page(id)
#' str(parse_col_page(pg))
parse_col_page <- function(page, types = c("scientific_names", "common_names")) {
  result <- list()
  json <- jsonlite::fromJSON(rawToChar(page$content), simplifyVector = FALSE)
  if (!is.empty(json$error_message)) {
    return(result)
  }
  if (length(json$results) > 1) {
    warning(paste0("Multiple pages found. Using only the first page."))
  }
  json <- json$results[[1]]
  if (length(json$accepted_name) > 0) {
    json <- json$accepted_name
  }
  json <- replace_values_in_list(json, "", NULL)
  ## Scientific names
  if ("scientific_names" %in% types) {
    canonical_name <- list(list(
      name = build_col_scientific_name(json),
      rank = json$rank,
      preferred = TRUE
    ))
    synonyms <- lapply(json$synonyms, function(synonym) {
      list(
        name = build_col_scientific_name(synonym),
        rank = synonym$rank,
        preferred = FALSE
      )
    })
    result$scientific_names <- c(canonical_name, unique(synonyms))
  }
  ## Common names
  if ("common_names" %in% types) {
    common_names <- lapply(json$common_names, function(x) {
      list(
        name = x$name,
        language = x$language,
        country = x$country
      )
    })
    result$common_names <- replace_values_in_list(common_names, NULL, NA)
  }
  ## Return
  return(result)
}

#' Build Catalogue of Life (COL) Scientific Name
#'
#' @family COL functions
#' @examples
#' id <- get_col_id("Malus domestica")
#' json <- content(get_col_page(id))$results[[1]]$accepted_name
#' build_col_scientific_name(json)
#' str(lapply(json$synonyms, build_col_scientific_name))
build_col_scientific_name = function(json) {
  if (is.null(json$genus)) {
    return(trimws(json$name))
  } else {
    return(trimws(with(json, paste(genus, species, infraspecies_marker, infraspecies))))
  }
}
