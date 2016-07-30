#' Query Sources about Falling Fruit (FF) Type
#'
#' @export
#' @family translation functions
#' @examples
#' ff_types <- get_ff_types(urls = TRUE)
#' get_ff_type_queries(ff_types[id == 14], sources = "eol")
get_ff_type_queries <- function(ff_type, sources = c("eol", "col", "inaturalist", "wikipedia", "wikicommons", "wikispecies")) {

  # Initialize type
  en_name <- ff_type$name
  scientific_name <- ff_type$scientific_name
  taxonomic_rank <- ff_type$taxonomic_rank
  wikipedia_url <- ff_type$wikipedia_url
  has_binomial_scientific_name <- all(length(strsplit(scientific_name, " ")[[1]]) == 2, !grepl("'", scientific_name))
  has_canonical_scientific_name <- !any(is.na(scientific_name), taxonomic_rank %in% c("Polyphyletic", "Multispecies"), (taxonomic_rank == "Subspecies" && has_binomial_scientific_name))

  # Initialize results
  queries <- list()

  ## Scientific databases
  if (has_canonical_scientific_name) {
    if ("eol" %in% sources) {
      id <- get_eol_id(scientific_name)
      if (!is.null(id)) {
        queries <- append(queries, list(source = "eol", response = get_eol_page(id, content_only = FALSE)))
      }
    }
    if ("col" %in% sources) {
      id <- get_col_id(scientific_name)
      if (!is.null(id)) {
        queries <- append(queries, list(source = "col", response = get_col_page(id, content_only = FALSE)))
      }
    }
    if ("inaturalist" %in% sources) {
      id <- get_inaturalist_id(scientific_name)
      if (!is.null(id)) {
        queries <- append(queries, list(source = "inaturalist", response = get_inaturalist_page(id, content_only = FALSE)))
      }
    }
  }

  ## Wikis
  if (any(grepl("^wiki", sources))) {
    page_title <- NULL
    if (!is.empty(wikipedia_url)) {
      page_title <- parse_wiki_url(wikipedia_url)[3]
    } else if (has_canonical_scientific_name) {
      page_title <- scientific_name
    }
    if (!is.empty(page_title)) {
      if ("wikipedia" %in% sources) {
        json <- get_wiki_page("en", "wikipedia", page_title)
        if (!is.empty(json)) {
          urls <- c(build_wiki_url("en", "wikipedia", page_title), sapply(json$langlinks, "[", "url"))
          for (url in urls) {
            response <- GET(url)
            response$content <- content(response)
            queries <- append(queries, list(source = "wikipedia", response = response))
          }
        }
      }
      if ("wikicommons" %in% sources) {
        if (!is.empty(get_wiki_page("commons", "wikimedia", page_title))) {
          url <- build_wiki_url("commons", "wikimedia", page_title)
          response <- GET(url)
          response$content <- content(response)
          queries <- append(queries, list(source = "wikicommons", response = response))
        }
      }
      if ("wikispecies" %in% sources) {
        if (!is.empty(get_wiki_page("species", "wikimedia", page_title))) {
          url <- build_wiki_url("species", "wikimedia", page_title)
          response <- GET(url)
          response$content <- content(response)
          queries <- append(queries, list(source = "wikispecies", response = response))
        }
      }
    }
  }

  # Return result
  return(queries)
}
