#' Get iNaturalist Taxon Search Results
#'
#' Undocumented, but equivalent to the HTML equivalent \url{http://www.inaturalist.org/taxa/search}.
#'
#' @param is_active Either 'true', 'false', or 'any'.
#' @export
#' @family iNaturalist functions
#' @examples
#' str(content(get_inaturalist_search("Malus domestica")))
#' str(content(get_inaturalist_search("Abelmoschus")))
#' str(content(get_inaturalist_search("Citrus x sinensis")))
get_inaturalist_search <- function(q, is_active = 'true') {
  q <- gsub("\\s*x\\s*", " × ", q)
  url <- parse_url("http://www.inaturalist.org/taxa/search.json")
  query <- mget(c("q", "is_active"))
  return(GET(url, query = query[sapply(query, "!=", "")]))
}

#' Parse iNaturalist Taxon Search Results
#'
#' @export
#' @family iNaturalist functions
#' @examples
#' s <- get_inaturalist_search("Malus domestica")
#' str(parse_inaturalist_search(s))
#' s <- get_inaturalist_search("Abelmoschus")
#' str(parse_inaturalist_search(s))
parse_inaturalist_search <- function(search, types = c("results", "ids"), exact = TRUE, scientific_name = TRUE, ignore.case = TRUE) {
  result <- list()
  json <- content(search)
  q <- parse_url(search$url)$query$q
  ## Filter results
  if (exact) {
    q <- paste0("^", q, "$")
  }
  ind <- unlist(sapply(json, function(result) {
    is_match <- grepl(q, sapply(result$taxon_names, "[[", "name"), ignore.case = ignore.case)
    is_scientific_name <- sapply(result$taxon_names, "[[", "lexicon") == "Scientific Names"
    if (scientific_name) {
      any(is_match & is_scientific_name)
    } else {
      any(is_match & !is_scientific_name)
    }
  }))
  ## Results
  if ("results" %in% types) {
    result$results <- json[ind]
  }
  ## IDs
  if ("ids" %in% types) {
    result$ids <- sapply(json[ind], "[[", "id")
  }
  ## Return
  return(result)
}

#' Get iNaturalist Taxon Page
#'
#' Undocumented, but equivalent to the HTML equivalent \url{http://www.inaturalist.org/taxa/:id.json}.
#'
#' @export
#' @family iNaturalist functions
#' @examples
#' s <- get_inaturalist_search("Malus domestica")
#' id <- parse_inaturalist_search(s, "ids")$ids[1]
#' str(content(get_inaturalist_page(id)))
get_inaturalist_page <- function(id) {
  url <- parse_url(paste0("http://www.inaturalist.org/taxa/", id, ".json"))
  return(GET(url))
}

#' Parse iNaturalist Taxon Page
#'
#' @export
#' @family iNaturalist functions
#' @examples
#' s <- get_inaturalist_search("Malus domestica")
#' id <- parse_inaturalist_search(s, "ids")$ids[1]
#' pg <- get_inaturalist_page(id)
#' str(parse_inaturalist_page(pg))
#' s <- get_inaturalist_search("Abelmoschus")
#' id <- parse_inaturalist_search(s, "ids")$ids[1]
#' pg <- get_inaturalist_page(id)
#' str(parse_inaturalist_page(pg))
parse_inaturalist_page <- function(page, types = c("scientific_names", "common_names")) {
  result <- list()
  json <- jsonlite::fromJSON(rawToChar(page$content), simplifyVector = FALSE)
  if (!is.null(json$error)) {
    return(result)
  }
  ## Scientific names
  if ("scientific_names" %in% types) {
    scientific_names <- unique(lapply(json$taxon_names, function(x) {
      if (!is.null(x$lexicon) && x$lexicon == "Scientific Names") {
        list(
          name = x$name,
          preferred = ifelse(!is.empty(x$is_valid) && x$is_valid, TRUE, FALSE)
        )
      }
    }))
    result$scientific_names <- scientific_names[!is.empty(scientific_names)]
  }
  ## Common names
  if ("common_names" %in% types) {
    common_names <- unique(lapply(json$taxon_names, function(x) {
      if (!is.null(x$lexicon) && x$lexicon != "" && x$lexicon != "Scientific Names") {
        list(
          name = x$name,
          language = x$lexicon,
          preferred = ifelse(!is.empty(x$is_valid) && x$is_valid, TRUE, FALSE)
        )
      }
    }))
    result$common_names <- common_names[!is.empty(common_names)]
  }
  ## Return
  return(result)
}
