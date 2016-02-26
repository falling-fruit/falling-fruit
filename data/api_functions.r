# Load libraries
library(httr)
library(RJSONIO)
library(plyr)
library(XML)

## Helper variables

taxonomic_ranks <- c("Polyphyletic", "Kingdom", "Phylum", "Class", "Order", "Family", "Genus", "Multispecies", "Species", "Subspecies")
language_codes <- read.csv('language_codes.csv', stringsAsFactors = FALSE, na.strings = "")
categories <- c("forager", "freegan", "honeybee", "grafter")

## Helper functions

list_to_dataframe <- function(x, stringsAsFactors = FALSE, ...) {
  x <- replace_in_list(x, NULL, NA)
  do.call("rbind.fill", lapply(x, as.data.frame, stringsAsFactors = stringsAsFactors, ...))
}

dataframe_to_list <- function(x) {
  # List each row of dataframe
  row_list <- unname(split(x, seq(nrow(x))))
  # Convert each row to list
  nested_list <- lapply(row_list, function(row) {as.list(row)})
  return(nested_list)
}

replace_in_list <- function(x, old.value = "", new.value= NULL) {
  lapply(x, function(x_i) {
    if (is.list(x_i)) {
      replace_in_list(x_i, old.value, new.value)
    } else {
      if (identical(x_i, old.value)) {
        new.value
      } else {
        x_i
      }
    }
  })
}

trimws <- function (x) {
  x <- gsub("^\\s+|\\s+$", "", x)
  x <- gsub("[ ]+", " ", x)
  return(x)
}

get_page_xml = function(url) {
  return(htmlParse(content(GET(url), "text"), asText = TRUE))
}

# (deprecated)
expand_dataframe_by_split = function(df, col.name, split = "[ ]*,[ ]*") {
  splits <- strsplit(as.character(df[[col.name]]), split)
  n_splits <- sapply(splits, FUN = length)
  df <- df[, -which(names(df) %in% col.name), drop = FALSE]
  df <- data.frame(unlist(splits), df[rep(seq_len(nrow(df)), n_splits), , drop = FALSE])
  names(df)[1] <- col.name
  return(df)
}

repeat_dataframe_rows = function(df, times) {
  rdf <- df[rep(seq_len(nrow(df)), times), , drop = FALSE]
  return(rdf)
}

expand_list_by_split = function(x, name, split = "[ ]*,[ ]*") {
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

group_dataframe_by_columns <- function(df, col.names, na.rm = FALSE) {
  plyr::ddply(df, col.names, colwise(function(x) {
    x <- unique(x)
    if (na.rm && !all(is.na(x))) {
      x <- x[!is.na(x)]
    }
    return(list(x))
  }))
}

expand_category_mask <- function(category_mask) {
  categories[which(as.numeric(intToBits(category_mask)) == 1)]
}

################
## Falling Fruit

get_ff_types <- function(categories = c("forager", "freegan"), uncategorized = FALSE, pending = FALSE, locale = "en", urls = FALSE) {
  ff_api <- parse_url("https://fallingfruit.org/api/0.2/types.json?api_key=BJBNKMWM")
  query <- list(c = paste(categories, collapse = ","), uncategorized = ifelse(uncategorized, 1, 0), pending = ifelse(pending, 1, 0), locale = locale, urls = ifelse(urls, 1, 0))
  url <- modify_url(ff_api, query = append(ff_api$query, query))
  json <- content(GET(url), "parse")
  df <- list_to_dataframe(json)
  # Sort species
  df <- df[order(df$scientific_name, df$taxonomic_rank, df$name), ]
  # Numeric => String taxonomic ranks
  df$taxonomic_rank <- taxonomic_ranks[df$taxonomic_rank + 1]
  return(df)
}

################
## Encyclopedia of Life (EOL)

get_eol_id <- function(scientific_name) {
  eol_search <- parse_url("http://eol.org/api/search/1.0.json?exact=true")
  query <- list(q = scientific_name)
  url <- modify_url(eol_search, query = append(eol_search$query, query))
  json <- content(GET(url), "parse")
  if (length(json$results) > 0 ) {
    return(json$results[[1]]$id)
  }
}

get_eol_page <- function(id) {
  
  # Initialize
  results <- list()
  eol_pages <- parse_url("http://eol.org/api/pages/1.0/?common_names=true&synonyms=true&references=true&taxonomy=true&details=true&images=75&iucn=true")
  url <- modify_url(eol_pages, path = paste0(eol_pages$path, id, ".json"))
  json <- content(GET(url), "parse")
  
  # Save page
  query <- list()
  query$type <- "eol"
  query$id <- id
  query$date <- Sys.time()
  query$url <- url
  query$response$json <- json
  return(query)
}

parse_eol_page <- function(query) {
  
  # Initialize
  json <- query$response$json
  if (length(json) == 0) {
    return(NULL)
  }
  results <- list()
  
  # Pages
  results$pages <- list(list(url = paste0("http://eol.org/pages/", json$identifier), language = "en"))
  
  # Scientific names
  # NOTE: Leaving out $synonyms[], using only $taxonConcepts[] (authoritative synonyms)
  if (length(json$taxonConcepts) > 0) {
    preferred_name <- unique(unlist(sapply(json$taxonConcepts, function(x) { 
      if (json$scientificName == x$scientificName) {
        x$canonicalForm
      }
    })))
    scientific_names <- lapply(json$taxonConcepts, function(x) {
      list(name = x$canonicalForm, rank = x$taxonRank, preferred = (x$canonicalForm == preferred_name))
    })
    scientific_names <- scientific_names[!duplicated(scientific_names)]
    results$scientific_names <- scientific_names
  }
  
  # Common names
  if (length(json$vernacularNames) > 0) {
    common_names <- lapply(json$vernacularNames, function(x) {
      name <- trimws(gsub("[ ]*\\(.*\\)", "", x$vernacularName))
      list(name = name, language = x$language, preferred = ifelse(is.null(x$eol_preferred), FALSE, x$eol_preferred))
    })
    # Expand comma-seperated values
    common_names <- expand_list_by_split(common_names, "name")
    results$common_names <- common_names
  }
  return(results)
}

##################
## Catalog of Life

get_col_id <- function(scientific_name) {
  col_api <- parse_url("http://www.catalogueoflife.org/col/webservice?format=json")
  query <- list(name = scientific_name)
  url <- modify_url(col_api, query = append(col_api$query, query))
  json <- content(GET(url), "parse")
  if (length(json$results) > 0) {
    return(json$results[[1]]$id)
  }
}

get_col_page <- function(id) {
  
  # Initialize
  col_api <- parse_url("http://www.catalogueoflife.org/col/webservice?format=json&response=full")
  query <- list(id = col_id)
  url <- modify_url(col_api, query = append(col_api$query, query))
  json.full <- content(GET(url), "parse")
  if (length(json.full$results) > 1) {
    warning("Multiple results from COL(id)!")
  }
  json <- json.full$results[[1]]
  if (length(json$accepted_name) > 0) {
    json <- json$accepted_name
  }
  json <- replace_in_list(json, "", NULL)
  
  # Save page
  query <- list()
  query$type <- "col"
  query$id <- json$id
  query$date <- Sys.time()
  query$url <- modify_url(col_api, query = append(col_api$query, list(id = json$id)))
  query$response$json <- json
  return(query)
}

parse_col_page <- function(query) {
  
  # Initialize
  json <- query$response$json
  if (length(json) == 0) {
    return(NULL)
  }
  results <- list()
  
  # Pages
  results$pages <- list(list(url = json$url, language = "en"))
  
  # Scientific names
  scientific_names <- list(list(name = build_col_scientific_name(json), rank = json$rank, preferred = TRUE))
  if (length(json$synonyms) > 0) {
    scientific_names <- append(scientific_names, lapply(json$synonyms, function(synonym) {
      list(name = build_col_scientific_name(synonym), rank = synonym$rank, preferred = FALSE)
    }))
  }
  results$scientific_names <- scientific_names
  
  # Common names
  if (length(json$common_names) > 0) {
    common_names <- lapply(json$common_names, function(x) {
      name <- trimws(gsub("[ ]*\\(.*\\)", "", x$name))
      list(name = name, language = normalize_col_language(x$language), country = x$country)
    })
    # Expand comma-seperated values
    common_names <- expand_list_by_split(common_names, "name")
    common_names <- expand_list_by_split(common_names, "language")
    results$common_names <- common_names
  }
  return(results)
}

build_col_scientific_name = function(json) {
  if (is.null(json$genus)) {
    return(json$name)
  } else {
    scientific_name <- trimws(with(json, paste(genus, species, infraspecies_marker, infraspecies)))
    return(scientific_name)
  }
}

normalize_col_language = function(x) {
  x <- tolower(x)
  if (length(x) == 0) {
    return(NA)
  }
  if (length(x) == 2) {
    ind <- which(language_codes$ISO6391 %in% x)
  }
  if (length(x) == 3) {
    ind <- which(language_codes$ISO6392.syn %in% x | language_codes$ISO6392 %in% x)
  }
  if (length(x) > 3) {
    ind <- which(language_codes$en_name %in% x)
  }
  if (length(ind) == 0) {
    warning(paste('COL language not recognized:', x))
    return(x)
  } else if (length(ind) == 1) {
    if (is.na(language_codes$ISO6391[ind])) {
      return(language_codes$ISO6392[ind])
    } else {
      return(language_codes$ISO6391[ind])
    }
  } else {
    warning(paste('COL language found multiple times:', x))
    return(x)
  }
}

## Wikipedia

get_wikipedia_page = function(page_title, language = "en", langlinks = TRUE) {
  
  # Initialize
  page_title <- gsub(" ", "_", page_title)
  url <- parse_url(paste0("https://", language, ".wikipedia.org/w/api.php?format=json&action=parse&redirects&page=", page_title))
  json.full <- content(GET(url), "parse")
  json <- json.full$parse
  if (is.null(json)) {
    return(NULL)
  }
  
  # Save page
  query <- list()
  query$type <- "wikipedia"
  query$language <- language
  query$id <- page_title
  query$date <- Sys.time()
  query$url <- url
  if (langlinks) {
    for (i in seq_len(length(json$langlinks))) {
      json$langlinks[[i]]$response$xml <- get_page_xml(json$langlinks[[i]]$url)
    }
  }
  query$response <- list(json = json, xml = get_page_xml(url))
  return(query)
}

parse_wikipedia_page = function(query) {
  
  # Initialize
  if (length(query$response) != 2) {
    warning(paste0("Wikipedia page missing json and xml: ", query$id, " (", query$language, ")"))
    return(NULL)
  }
  json <- query$response$json
  xml <- query$response$xml
  results <- list()
  
  # Current page
  url <- paste0("https://", query$language, ".wikipedia.org/wiki/", query$id)
  pages <- list(list(url = url, language = language))
  common_names <- lapply(parse_wikipedia_names(xml), function(name) {
    list(name = name, language = query$language)
  })
  
  # Language pages
  for (i in seq_len(length(json$langlinks))) {
    link <- json$langlinks[[i]]
    pages <- append(pages, list(list(url = link$url, language = link$lang)))
    if (!is.null(link$response$xml)) {
      link_names <- lapply(parse_wikipedia_names(link$response$xml), function(name) {
        list(name = name, language = link$lang)
      })
      common_names <- append(common_names, link_names)
    }
  }
  results$pages <- pages
  results$common_names <- common_names
  return(results)
}

parse_wikipedia_names = function(xml) {
  first_p_bolds <- xpathApply(xml, path = "//div[@id='mw-content-text']/p[position() < 3]//b[not(parent::*[self::i]) and not(i)]")
  biotabox_header <- xpathApply(xml, path = "//table[contains(@class, 'infobox biota')]//th[1][not(i)]")
  names <- lapply(append(first_p_bolds, biotabox_header), function(x) {
    xmlValue(x)
  })
  if (length(names) > 0) {
    names <- unique(unlist(strsplit(names, "[ ]*,[ ]*")))
    names <- gsub("\\.|\\n|\\t|\\?|[ ]*\\(.*\\)|\"", "", names)
    names <- trimws(names)
    names <- names[names != ""]
    if (length(names) > 0) {
      return(names)
    }
  }
}

get_wikicommons_page = function(page_title) {

  # Initialize
  page_title <- gsub(" ", "_", page_title)
  url <- paste0("https://commons.wikimedia.org/wiki/", page_title)
  xml <- get_page_xml(url)
  if (is.null(xml)) {
    return(NULL)
  }
  
  # Save page
  query <- list()
  query$type <- "wikicommons"
  query$id <- page_title
  query$date <- Sys.time()
  query$url <- url
  query$response$xml <- xml
  return(query)
}

parse_wikicommons_page = function(query) {
  
  # Initialize
  if (is.null(query$response$xml)) {
    return(NULL)
  }
  results <- list()
  
  # Pages
  results$pages <- list(list(url = query$url, language = "en"))
  
  # Common names
  results$common_names <- parse_wikicommons_names(query$response$xml)
  return(results)
}

parse_wikicommons_names = function(xml) {
  #<bdi class="vernacular" lang="en"><a href="">common name</a></bdi>
  #<bdi class="vernacular" lang="en">common name</bdi>
  vernacular_html <- xpathApply(xml, path = "//bdi[@class='vernacular']")
  common_names <- lapply(vernacular_html, function(x) {
    attributes <- xmlAttrs(x)
    lang <- attributes[["lang"]]
    name <- trimws(gsub("[ ]*\\(.*\\)", "", xmlValue(x)))
    list(name = name, language = lang)
  })
  if (length(common_names) > 0) {
    common_names <- expand_list_by_split(common_names, "name", split = "[ ]*[,|/][ ]*")
    return(common_names)
  }
}

# UNUSED
# TODO: Parse language autonyms
parse_wikispecies_names = function(url) {
  xml <- get_page_xml(url)
  vernacular_html <- xpathApply(xml, path = "//h2/span[@id='Vernacular_names']/parent::*/following-sibling::div[1]")[[1]]
  # <b>language:</b>&nbsp;[name|<a>name</a>]
  languages_html <- xpathApply(vernacular_html, path = "b")
  languages <- sapply(languages_html, function(x) {
    return(trimws(strsplit(xmlValue(x), ":")[[1]][1]))
  })
  names_html <- xpathApply(vernacular_html, path = "b[not(following-sibling::*[1][self::a])]/following-sibling::text()[1] | b/following-sibling::*[1][self::a]/text()")
  names <- sapply(names_html, function(x) {
    return(trimws(xmlValue(x)))
  })
  df <- data.frame(language = languages, name = names)
  df <- split_column_to_rows(df, "name")
  return(df)
}

## Search Engines

# Google Web Search
# free, deprecated, quotas unknown (but restrictive)

count_google_ws_results = function(string) {
  google_ws_api <- parse_url("https://ajax.googleapis.com/ajax/services/search/web?v=1.0")
  query <- list(q = string)
  url <- modify_url(google_ws_api, query = append(google_ws_api$query, query))
  json <- content(GET(url), "parse", type = "application/json")
  if (!is.null(json$responseData)) {
    return(as.integer(json$responseData$cursor$estimatedResultCount))
  }
}

# Google Custom Search
# free: 100 / day, max: 10,000 / day, rate limit: 1 / s
# https://developers.google.com/custom-search/json-api/v1/overview

google_cs_languages <- c("ar", "bg", "ca", "cs", "da", "de", "el", "en", "es", "et", "fi", "fr", "hr", "hu", "id", "is", "it", "iw", "ja", "ko", "lt", "lv", "nl", "no", "pl", "pt", "ro", "ru", "sk", "sl", "sr", "sv", "tr", "zh-cn", "zh-tw")

count_google_cs_results = function(string, language = NULL) {
  google_cs_api <- parse_url("https://www.googleapis.com/customsearch/v1?key=AIzaSyDm7gTRTOlOIsum_KOwfM-X13RYexMW41M&cx=017771660208863495094:7npb6irvsc0")
  if (!is.null(language) && !(language %in% google_cs_languages)) {
    stop("Unsupported language: '", language, "'")
  }
  query <- list(q = string)
  if (!is.null(language)) {
    query <- c(query, lr = paste0("lang_", language))
  }
  url <- modify_url(google_cs_api, query = append(google_cs_api$query, query))
  json <- content(GET(url), "parse", type = "application/json")
  if (!is.null(json$queries$request)) {
    return(as.integer(json$queries$request[[1]]$totalResults))
  }
}

# Gigablast Search
# free, no quota, smaller database
# https://gigablast.com/api.html

count_gigablast_results = function(string) {
  gigablast_search_api <- parse_url("http://www.gigablast.com/search?format=json&rxiwd=1608781976")
  query <- list(q = string)
  url <- modify_url(gigablast_search_api, query = append(gigablast_search_api$query, query))
  #json <- content(GET(url), "parse") # Invalid character errors
  txt <- content(GET(url), "text")
  json <- fromJSON(txt)
  if (!is.null(json$hits)) {
    return(json$hits)
  }
}