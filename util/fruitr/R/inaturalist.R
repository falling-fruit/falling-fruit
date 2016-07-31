#' Get iNaturalist Taxon ID
#'
#' @export
#' @family iNaturalist functions
#' @examples
#' get_inaturalist_id("Malus domestica")
get_inaturalist_id <- function(search_string) {
  url <- parse_url("http://www.inaturalist.org/taxa/search.json")
  query <- list(q = search_string)
  json <- content(GET(url, query = query))
  if (is.list(json) && length(json) > 0) {
    return(json[[1]]$id)
  }
}

#' Get iNaturalist Taxon Page
#'
#' @export
#' @family iNaturalist functions
#' @examples
#' id <- get_inaturalist_id("Malus domestica")
#' str(get_inaturalist_page(id))
get_inaturalist_page <- function(id, content_only = TRUE) {
  url <- parse_url("http://www.inaturalist.org/taxa/")
  path <- paste0(id, ".json")
  response <- GET(url, path = paste0(url$path, path))
  json <- content(response)
  if (!is.list(json) || length(json) == 0) {
    json <- NULL
  }
  if (content_only) {
    return(json)
  } else {
    response$content <- json
    return(response)
  }
}

#' Parse iNaturalist Scientific Names
#'
#' @export
#' @family iNaturalist functions
#' @examples
#' id <- get_inaturalist_id("Malus domestica")
#' json <- get_inaturalist_page(id)
#' parse_inaturalist_scientific_names(json)
parse_inaturalist_scientific_names <- function(json) {
  scientific_names <- unique(lapply(json$taxon_names, function(x) {
    if (x$lexicon == "Scientific Names") {
      list(
        name = x$name,
        preferred = ifelse(!is.empty(x$is_valid) && x$is_valid, TRUE, FALSE)
      )
    }
  }))
  return(scientific_names[!is.empty(scientific_names)])
}

#' Parse iNaturalist Common Names
#'
#' @export
#' @family iNaturalist functions
#' @examples
#' id <- get_inaturalist_id("Malus domestica")
#' json <- get_inaturalist_page(id)
#' parse_inaturalist_common_names(json)
parse_inaturalist_common_names <- function(json) {
  common_names <- unique(lapply(json$taxon_names, function(x) {
    if (x$lexicon != "Scientific Names" && x$lexicon != "") {
      list(
        name = x$name,
        language = normalize_language(x$lexicon),
        preferred = ifelse(!is.empty(x$is_valid) && x$is_valid, TRUE, FALSE)
      )
    }
  }))
  return(common_names[!is.empty(common_names)])
}
