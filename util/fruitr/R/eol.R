#' Get Encyclopedia of Life (EOL) ID
#'
#' For reliable results, search string must be a scientific name.
#' See documentation at http://eol.org/api/docs/search.
#'
#' @family EOL functions
#' @export
#' @examples
#' get_eol_id("Malus pumila")
#' get_eol_id("Abelmoschus")
#' get_eol_id("Prunus")
get_eol_id <- function(search_string, exact = TRUE) {
  url <- parse_url("http://eol.org/api/search/1.0.json")
  query <- list(exact = TRUE, q = search_string, exact = exact)
  json <- content(GET(url, query = query))
  if (is.list(json) && length(json$results) > 0 ) {
    return(json$results[[1]]$id)
  }
}

#' Get Encyclopedia of Life (EOL) Page
#'
#' See documentation at http://eol.org/api/docs/pages.
#'
#' @family EOL functions
#' @export
#' @examples
#' id <- get_eol_id("Malus domestica")
#' str(get_eol_page(id))
get_eol_page <- function(id, common_names = TRUE, synonyms = TRUE, references = TRUE, taxonomy = TRUE, details = TRUE, iucn = TRUE, images = 75, content_only = TRUE) {
  url <- parse_url(paste0("http://eol.org/api/pages/1.0/", id, ".json"))
  query <- mget(c("common_names", "synonyms", "references", "taxonomy", "details", "iucn", "images"))
  response <- GET(url, query = query)
  json <- content(response)
  if (!is.list(json) || length(json) == 0 ) {
    json <- NULL
  }
  if (content_only) {
    return(json)
  } else {
    return(list(source = "eol", date = response$date, url = response$url, status_code = response$status_code, json = json))
  }
}

#' Parse Encyclopedia of Life (EOL) Scientific Names
#'
#' @family EOL functions
#' @export
#' @examples
#' id <- get_eol_id("Malus domestica")
#' json <- get_eol_page(id)
#' parse_eol_scientific_names(json)
parse_eol_scientific_names <- function(json) {
  canonical_names <- unique(lapply(json$taxonConcepts, function(x) {
    list(
      name = x$canonicalForm,
      rank = x$taxonRank,
      preferred = TRUE)
  }))
  synonyms <- unique(lapply(json$synonyms, function(x) {
    name <- gsub("\\s*\\([^\\)]*\\)|,.*$", "", x$synonym) # Parentheses or after first comma
    name <- gsub("( [A-Za-z]+\\.)+$", "", name) # Ending abbreviated words
    if (name %in% sapply(canonical_names, `[`, "name")) {
      return(NULL)
    } else {
      list(
        name = name,
        rank = NA,
        preferred = FALSE
      )
    }
  }))
  return(c(canonical_names, synonyms[!is.empty(synonyms)]))
}

#' Parse Encyclopedia of Life (EOL) Common Names
#'
#' @family EOL functions
#' @export
#' @examples
#' id <- get_eol_id("Malus domestica")
#' json <- get_eol_page(id)
#' parse_eol_common_names(json)
parse_eol_common_names <- function(json) {
  common_names <- lapply(json$vernacularNames, function(x) {
    list(
      name = x$vernacularName,
      language = x$language,
      preferred = ifelse(is.null(x$eol_preferred), FALSE, TRUE)
    )
  })
  return(common_names)
}
