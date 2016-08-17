#' Query Sources about Falling Fruit (FF) Type
#'
#' @export
#' @family translation functions
#' @examples
#' ff_types <- get_ff_types(urls = TRUE)
#' query_sources_about_type(ff_types[id == 14], sources = "eol")
query_sources_about_type <- function(ff_type, sources = c("eol", "col", "inaturalist", "wikipedia", "wikicommons", "wikispecies")) {

  # Initialize type
  en_name <- ff_type$name
  scientific_name <- ff_type$scientific_name
  taxonomic_rank <- ff_type$taxonomic_rank
  wikipedia_url <- ff_type$wikipedia_url
  has_binomial_scientific_name <- all(length(strsplit(scientific_name, " ")[[1]]) == 2, !grepl("'", scientific_name))
  has_canonical_scientific_name <- !any(is.na(scientific_name), taxonomic_rank %in% c("Polyphyletic", "Multispecies"), (taxonomic_rank == "Subspecies" && has_binomial_scientific_name))

  # Initialize results
  responses <- list()

  ## Scientific databases
  if (has_canonical_scientific_name) {
    if ("eol" %in% sources) {
      id <- get_eol_id(scientific_name)
      if (!is.null(id)) {
        responses <- append(responses, list(get_eol_page(id, content_only = FALSE)))
      }
    }
    if ("col" %in% sources) {
      id <- get_col_id(scientific_name)
      if (!is.null(id)) {
        responses <- append(responses, list(get_col_page(id, content_only = FALSE)))
      }
    }
    if ("inaturalist" %in% sources) {
      id <- get_inaturalist_id(scientific_name)
      if (!is.null(id)) {
        responses <- append(responses, list(get_inaturalist_page(id, content_only = FALSE)))
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
        if (!is.null(json)) {
          urls <- c(build_wiki_url("en", "wikipedia", page_title), sapply(json$langlinks, "[", "url"))
          for (url in urls) {
            response <- get_page(url, content_only = FALSE)
            response$source <- "wikipedia"
            responses <- append(responses, list(response))
          }
        }
      }
      if ("wikicommons" %in% sources) {
        url <- build_wiki_url("commons", "wikimedia", page_title)
        response <- get_page(url, content_only = FALSE)
        response$source <- "wikicommons"
        responses <- append(responses, list(response))
      }
      if ("wikispecies" %in% sources) {
        url <- build_wiki_url("species", "wikimedia", page_title)
        response <- get_page(url, content_only = FALSE)
        response$source <- "wikispecies"
        responses <- append(responses, list(response))
      }
    }
  }

  # Return result
  return(responses)
}
