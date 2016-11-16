#' Get Encyclopedia of Life (EOL) Search Results
#'
#' See documentation at \url{http://eol.org/api/docs/search}. Alterations to default parameter values:
#' exact: FALSE => TRUE
#'
#' NOTE: For reliable results, run an exact search (exact = TRUE) with a scientific name search string (q).
#'
#' @family EOL functions
#' @export
#' @examples
#' str(content(get_eol_search("Malus domestica"))) # few equivalent results
#' str(content(get_eol_search("Abelmoschus"))) # one result
#' str(content(get_eol_search("Forbidden fruit"))) # no results
get_eol_search <- function(q, page = 1, exact = TRUE, filter_by_taxon_concept_id, filter_by_hierarchy_entry_id, filter_by_string, cache_ttl) {
  url <- parse_url("http://eol.org/api/search/1.0.json")
  query <- mget(c("q", "page", "exact", "filter_by_taxon_concept_id", "filter_by_hierarchy_entry_id", "filter_by_string", "cache_ttl"))
  return(GET(url, query = query[sapply(query, "!=", "")]))
}

#' Parse Encyclopedia of Life (EOL) Search Results
#'
#' @family EOL functions
#' @export
#' @examples
#' s <- get_eol_search("Malus domestica")
#' str(parse_eol_search(s)) # few equivalent results
#' s <- get_eol_search("Abelmoschus")
#' str(parse_eol_search(s)) # one result
#' s <- get_eol_search("Forbidden fruit")
#' str(parse_eol_search(s)) # no results
parse_eol_search <- function(search, types = c("results", "ids")) {
  result <- list()
  json <- content(search)
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

#' Get Encyclopedia of Life (EOL) Page
#'
#' See documentation at \url{http://eol.org/api/docs/pages}. Alterations to default parameter values:
#' common_names: FALSE => TRUE
#' synonyms: FALSE => TRUE
#'
#' @family EOL functions
#' @export
#' @examples
#' s <- get_eol_search("Malus domestica")
#' id <- parse_eol_search(s, "ids")$ids[1]
#' str(content(get_eol_page(id)))
get_eol_page <- function(id, batch = FALSE, images_per_page, images_page = 1, videos_per_page, videos_page = 1, sounds_per_page, sounds_page = 1, maps_per_page, maps_page = 1, texts_per_page, texts_page = 1, iucn = FALSE, subjects = "overview", licenses = "all", details = FALSE, common_names = TRUE, synonyms = TRUE, references = FALSE, taxonomy = TRUE, vetted = 0, cache_ttl, language = "en") {
  url <- parse_url(paste0("http://eol.org/api/pages/1.0/", id, ".json"))
  query <- mget(c("batch", "images_per_page", "images_page", "videos_per_page", "videos_page", "sounds_per_page", "sounds_page", "maps_per_page", "maps_page", "texts_per_page", "texts_page", "iucn", "subjects", "licenses", "details", "common_names", "synonyms", "references", "taxonomy", "vetted", "cache_ttl", "language"))
  return(GET(url, query = query[sapply(query, "!=", "")]))
}

#' Parse Encyclopedia of Life (EOL) Page
#'
#' @family EOL functions
#' @export
#' @examples
#' s <- get_eol_search("Malus domestica")
#' id <- parse_eol_search(s, "ids")$ids[1]
#' pg <- get_eol_page(id)
#' str(parse_eol_page(pg))
parse_eol_page <- function(page, types = c("scientific_names", "common_names")) {
  result <- list()
  json <- jsonlite::fromJSON(rawToChar(page$content), simplifyVector = FALSE)
  if (!is.null(unlist(json, recursive = FALSE)$error)) {
    return(result)
  }
  ## Scientific names
  if ("scientific_names" %in% types) {
    canonical_names <- unique(lapply(json$taxonConcepts, function(x) {
      list(
        # eol_id = x$identifier,
        # source = x$nameAccordingTo,
        name = x$canonicalForm,
        rank = x$taxonRank,
        preferred = TRUE
      )
    }))
    synonyms <- unique(lapply(json$synonyms, function(x) {
      list(
        # source = x$resource,
        # relationship = x$relationship,
        name = format_strings(x$synonym, "printed_scientific_name"),
        rank = NA,
        preferred = FALSE
      )
    }))
    result$scientific_names <- c(canonical_names, synonyms)
  }
  ## Common names
  if ("common_names" %in% types) {
    common_names <- lapply(json$vernacularNames, function(x) {
      list(
        name = x$vernacularName,
        language = x$language,
        preferred = ifelse(is.null(x$eol_preferred), FALSE, TRUE)
      )
    })
    result$common_names <- common_names
  }
  ## Return
  return(result)
}
