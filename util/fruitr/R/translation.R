#' Query Sources about Falling Fruit (FF) Type
#'
#' TODO: Seach by scientific synonyms if no results found.
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
      s <- get_eol_search(scientific_name, exact = TRUE)
      ids <- parse_eol_search(s, types = "ids")$ids
      if (length(ids) > 0) {
        if (length(ids) > 1) {
          warning(paste0("[", scientific_name, "] [eol] Multiple results found. Using first result."))
        }
        response <- get_eol_page(ids[1])
        response$source <- "eol"
        # response$parsed <- parse_eol_page(response)
        responses <- append(responses, list(response))
      }
    }
    if ("col" %in% sources) {
      s <- get_col_search(scientific_name)
      ids <- parse_col_search(s, types = "ids", exact = TRUE, scientific_name = TRUE, accepted_name = TRUE, ignore.case = TRUE)$ids
      if (length(ids) > 0) {
        if (length(ids) > 1) {
          warning(paste0("[", scientific_name, "] [col] Multiple results found. Using first result."))
        }
        response <- get_col_page(ids[1])
        response$source <- "col"
        # response$parsed <- parse_col_page(response)
        responses <- append(responses, list(response))
      }
    }
    if ("inaturalist" %in% sources) {
      s <- get_inaturalist_search(scientific_name, is_active = 'true')
      ids <- parse_inaturalist_search(s, types = "ids", exact = TRUE, scientific_name = TRUE, ignore.case = TRUE)$ids
      if (length(ids) > 0) {
        if (length(ids) > 1) {
          warning(paste0("[", scientific_name, "] [inaturalist] Multiple results found. Using first result."))
        }
        response <- get_inaturalist_page(ids[1])
        response$source <- "inaturalist"
        # response$parsed <- parse_inaturalist_page(response)
        responses <- append(responses, list(response))
      }
    }
  }

  ## Wikis
  if (any(grepl("^wiki", sources))) {
    page_title <- NULL
    if (!is.empty(wikipedia_url)) {
      page_title <- parse_wiki_url(wikipedia_url)$page
    } else if (has_canonical_scientific_name) {
      page_title <- scientific_name
    }
    if (!is.empty(page_title)) {
      if ("wikipedia" %in% sources) {
        url <- build_wiki_url("en", "wikipedia", page_title)
        response <- get_wiki_page(url)
        response$source <- "wikipedia"
        # response$parsed <- parse_wikipedia_page(response)
        responses <- append(responses, list(response))
        for (langlink in response$parsed$langlinks) {
          response <- get_wiki_page(langlink$url)
          response$source <- "wikipedia"
          # response$parsed <- parse_wikipedia_page(response)
          responses <- append(responses, list(response))
        }
      }
      if ("wikicommons" %in% sources) {
        url <- build_wiki_url("commons", "wikimedia", page_title)
        response <- get_wiki_page(url)
        response$source <- "wikicommons"
        # response$parsed <- parse_wikicommons_page(response)
        responses <- append(responses, list(response))
      }
      if ("wikispecies" %in% sources) {
        url <- build_wiki_url("species", "wikimedia", page_title)
        response <- get_wiki_page(url)
        response$source <- "wikispecies"
        # response$parsed <- parse_wikispecies_page(response)
        responses <- append(responses, list(response))
      }
    }
  }

  # Return result
  return(responses)
}

parse_sources_about_type <- function(responses) {
  responses <- lapply(responses, function(r) {
    r$parsed <- eval(parse(text = paste0("parse_", r$source, "_page(r)")))
    return(r)
  })
  return(responses)
}

build_scientific_name_table <- function(responses, ff_type) {

  # Aggregate scientific names
  scientific_name_lists <- lapply(responses, function(response) {
    temp <- response$parsed$scientific_names
    if (length(temp) > 0) {
      return(mapply(c, temp, source = response$source, url = response$url, SIMPLIFY = FALSE, USE.NAMES = FALSE))
    }
  })

  # Add Falling Fruit scientific names
  # TODO: Collect Falling Fruit API calls in responses?
  if (length(unlist(ff_type$scientific_names)) > 0) {
    ff_scientific_names <- unlist(ff_type$scientific_names)
    ff_scientific_name_list <- mapply(list, name = ff_scientific_names, rank = ff_type$taxonomic_rank, preferred = c(TRUE, rep(FALSE, length(ff_scientific_names) - 1)), source = "ff", SIMPLIFY = FALSE, USE.NAMES = FALSE)
    scientific_name_lists <- append(scientific_name_lists, list(ff_scientific_name_list))
  }

  # Convert to data.table
  scientific_name_lists <- unlist(scientific_name_lists[!is.empty(scientific_name_lists)], recursive = FALSE)
  scientific_name_lists <- replace_values_in_list(scientific_name_lists, NULL, NA)
  scientific_names <- rbindlist(scientific_name_lists, fill = TRUE)

  # Clean and filter
  if (nrow(scientific_names) > 0) {
    # Clean names
    scientific_names[, name := clean_strings(name)]

    # Rank names (count preferred)
    preferred_scientific_names <- scientific_names[preferred == TRUE, .(n = length(unique(source))), by = name][n == max(n), name]
    preferred_scientific_name <- ifelse(length(preferred_scientific_names) == 1, preferred_scientific_names, ff_type$scientific_name)
    if (preferred_scientific_name != ff_type$scientific_names[[1]][1]) {
      warning(paste0(ff_id, ": Preferred scientific name change [", ff_type$scientific_names[1], " => ", preferred_scientific_name, "]"))
    }
    scientific_names[name == preferred_scientific_name, ff_preferred := TRUE]
  }

  # Return
  return(scientific_names[])
}

build_common_name_table <- function(responses, scientific_names = NULL, normalize_languages = FALSE, search_names = FALSE) {

  # Aggregate common names
  common_name_lists <- lapply(responses, function(response) {
    temp <- response$parsed$common_names
    if (length(temp) > 0) {
      return(mapply(c, temp, source = response$source, url = response$url, SIMPLIFY = FALSE, USE.NAMES = FALSE))
    }
  })

  # Convert to data.table
  common_name_lists <- unlist(common_name_lists[!is.empty(common_name_lists)], recursive = FALSE)
  common_name_lists <- replace_values_in_list(common_name_lists, NULL, NA)
  common_names <- rbindlist(common_name_lists, fill = TRUE)
  if (nrow(common_names) == 0) {
    return(common_names)
  }

  # Clean names
  common_names[, name := clean_strings(name)]
  # Clean languages
  common_names[, language := clean_strings(language)]
  # Normalize languages
  if (normalize_languages) {
    common_names[, original_language := language]
    common_names[source != "wikipedia", language := normalize_language(language), by = language]
    common_names[source == "wikipedia", language := normalize_language(language, "wikipedia"), by = language]
    common_names[, is_recognized_language := !is.na(language)]
    common_names[is_recognized_language == FALSE, language := original_language]
  }

  # Filter names
  if (!is.null(scientific_names)) {
    # != scientific names (or whole word subset)
    # FIXME: Check if problem for Italian?
    common_names[, is_scientific_name := tolower(name) %in% unique(tolower(scientific_names$name)), by = name]
    common_names[, is_scientific_substring := sapply(lapply(tolower(name), grepl, x = unique(tolower(scientific_names$name)), fixed = TRUE), sum) > 1 & !is_scientific_name, by = name]
    # common_names <- common_names[!(name %in% scientific_names$name)]
    # is_scientific_substring <- colSums(sapply(paste0("(^| )", common_names$name, "($| )"), grepl, x = scientific_names$name, ignore.case = TRUE)) > 1
    # common_names <- common_names[!is_scientific_substring]
    # TODO: Character-based filter

    # Search names (appended to preferred scientific name)
    if (search_names) {
      preferred_scientific_name <- unique(scientific_names[ff_preferred == TRUE, name])
      # NOTE: "-" equivalent to " " in Google Search
      common_names[, search_name := tolower(gsub("-", " ", name))]
      # Count search results
      # Skip duplicate name-language pairs
      common_names[, search_string := paste0("'", preferred_scientific_name, "'+'", search_name, "'"), by = search_name]
      common_names[, search_results := count_google_cs_results(search_string, language), by = .(search_string, language)]
      # Subset results by language
      common_names[, subset_search_results := subset_search_results(name, search_results), by = language]
    }
  }

  # Rank common names
  # Top name by most preferred
  # common_names[, .(n = sum(preferred, na.rm = TRUE)), by = .(search_name, language)][, .(search_name = search_name[max(n) == n]), by = language]
  # Top name by most sources
  # common_names[, .(n = length(unique(source))), by = .(search_name, language)][, .(search_name = search_name[max(n) == n]), by = language]
  # Top name by most search results
  # common_names[, .(n = unique(subset_search_results)), by = .(search_name, language)][, .(search_name = search_name[max(n) == n]), by = language]
  # Rank names by search results
  # common_names[order(-subset_search_results), .(n = unique(subset_search_results)), by = .(search_name, language)][, .(search_names = list(search_name)), by = language]

  # Return
  return(common_names[])
}

normalize_common_name <- function(x, x_lower = NULL, x_search = NULL) {
  if (is.null(x_lower)) {
    x_lower <- tolower(x)
  }
  if (is.null(x_search)) {
    x_search <- gsub("-", " ", x_lower)
  }
  if (length(unique(x_search)) > 1) {
    stop(paste0("Group contains non-equal (search) values: ", paste(x, collapse = ", ")))
  }
  has_upper <- x != x_lower
  has_dash <- x_lower != x_search
  ind <- which.max(rowSums(cbind(has_upper * 2, has_dash)))
  return(capitalize_words(x[ind], first = TRUE))
}
