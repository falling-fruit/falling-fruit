library(data.table)

# Save settings
output_dir <- "~/sites/falling-fruit-data/fruitr/"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

## Load types
ff_types <- get_ff_types(urls = TRUE)
for (ff_id in ff_types$id) {
  ff_type <- ff_types[id == ff_id]

  #### Collect data ####
  # responses: source | url | date | status_code | xml/json/...
  # common_names: source | url | name | language | country | preferred
  # scientific_names: source | url | name | rank | preferred
  # search_results: search_string | language | results | date | url

  ## Query sources
  responses <- query_sources_about_type(ff_type)
  # responses <- mapply(c, id = ff_id, responses, SIMPLIFY = FALSE, USE.NAMES = FALSE)
  # Response list to table
  # dt <- rbindlist(lapply(responses, "[", c("source", "date", "url", "status_code")), fill = TRUE)
  # dt[, xml := sapply(responses, "[", "xml")]
  # dt[, json := sapply(responses, "[", "json")]
  # dt[, id := ff_id]

  ## Save results
  saveRDS(responses, paste0(output_dir, ff_id, "_responses.rds"))
  if (length(responses) == 0) {
    next
  }

  #### Parse scientific names ####

  ## Aggregate scientific names
  scientific_name_lists <- lapply(responses, function(response) {
    if (response$source %in% c("eol", "col", "inaturalist")) {
      temp <- eval(parse(text = paste0("parse_", response$source, "_scientific_names(response$", ifelse(is.null(response$xml), "json", "xml"), ")")))
      if (length(temp) > 0) {
        return(mapply(c, temp, source = response$source, url = response$url, SIMPLIFY = FALSE, USE.NAMES = FALSE))
      }
    }
  })
  scientific_names <- rbindlist(lapply(scientific_name_lists, rbindlist), fill = TRUE)
  # Clean name strings
  scientific_names[, name := clean_strings(name)]
  #scientific_names[, id := ff_id]

  ## Rank scientific names
  # # Count search results
  # scientific_names[, search_results := count_google_cs_results(paste0("\"", name, "\"")), by = name]
  # scientific_names[, subset_search_results := subset_search_results(name, search_results)]
  # Count preferred
  preferred_scientific_names <- scientific_names[preferred == TRUE, .(n = length(unique(source))), by = name][n == max(n), name]
  preferred_scientific_name <- ifelse(length(preferred_scientific_names) == 1, preferred_scientific_names, ff_type$scientific_names[1])
  if (preferred_scientific_name != ff_type$scientific_names[[1]][1]) {
    warning(paste0(ff_id, ": Preferred scientific name change [", ff_type$scientific_names[1], " => ", preferred_scientific_name, "]"))
  }
  scientific_names[name == preferred_scientific_name, ff_preferred := TRUE]

  ## Save results
  saveRDS(scientific_names, paste0(output_dir, ff_id, "_scientific_names.rds"))

  #### Parse common names ####

  ## Aggregate common names
  common_name_lists <- lapply(responses, function(response) {
    temp <- eval(parse(text = paste0("parse_", response$source, "_common_names(response$", ifelse(is.null(response$xml), "json", "xml"), ")")))
    if (length(temp) > 0) {
      return(mapply(c, temp, source = response$source, url = response$url, SIMPLIFY = FALSE, USE.NAMES = FALSE))
    }
  })
  common_names <- rbindlist(lapply(common_name_lists, rbindlist), fill = TRUE)
  # Clean name strings
  common_names[, name := clean_strings(name)]
  # Clean language strings
  common_names[, language := clean_strings(language)]
  # Normalize language strings
  common_names[, language := normalize_language(language), by = language]
  #common_names[, id := ff_id]

  ## Filter common names
  # != scientific names (or whole word subset)
  # common_names <- common_names[!(name %in% scientific_names$name)]
  is_scientific_substring <- colSums(sapply(paste0("(^| )", common_names$name, "($| )"), grepl, x = scientific_names$name, ignore.case = TRUE)) > 1
  common_names <- common_names[!is_scientific_substring]

  ## Search common names (appended to preferred scientific name)
  # Count search results
  # NOTE: "-" equivalent to " " in Google Search
  common_names[, search_name := tolower(gsub("-", " ", name))]
  # Skip duplicate name-language pairs
  common_names[, search_string := paste0("'", preferred_scientific_name, "'+'", search_name, "'"), by = search_name]
  common_names[, search_results := count_google_cs_results(search_string, language), by = .(search_string, language)]
  # Subset results by language
  common_names[, subset_search_results := subset_search_results(name, search_results), by = language]
  # Convert to fraction of max search results
  # common_names[, max_search_results := count_google_cs_results(paste0("'", preferred_scientific_name, "'"), language), by = language]
  # common_names[, subset_fractional_search_results := subset_search_results / max_search_results]

  ## Rank common names
  # Top name by most preferred
  # common_names[, .(n = sum(preferred, na.rm = TRUE)), by = .(search_name, language)][, .(search_name = search_name[max(n) == n]), by = language]
  # Top name by most sources
  # common_names[, .(n = length(unique(source))), by = .(search_name, language)][, .(search_name = search_name[max(n) == n]), by = language]
  # Top name by most search results
  # common_names[, .(n = unique(subset_search_results)), by = .(search_name, language)][, .(search_name = search_name[max(n) == n]), by = language]
  # Rank names by search results
  # common_names[order(-subset_search_results), .(n = unique(subset_search_results)), by = .(search_name, language)][, .(search_names = list(search_name)), by = language]

  ## Save results
  saveRDS(common_names, paste0(output_dir, ff_id, "_common_names.rds"))
}


#### Format results ####

## Falling Fruit (present)
# {locale}_names.csv
# ff_id | translated_name

languages = unique(common_names$language)
for (l in languages) {
  dt <- data.table(
    ff_id = ff_id,
    translated_name = common_names[language == l, .(n = unique(subset_search_results)), by = search_name][n == max(n), search_name])
  write.csv(dt, paste0("~/desktop/", l, "_names.csv"), row.names = FALSE)
}

## EOL
# common names.txt (by source, excluding eol)
# taxonID | vernacularName | source | language | locality | countryCode | isPreferredName | taxonRemarks

eol_id <- responses[sapply(responses, "[", "source") == "eol"][[1]]$json$identifier
sources = unique(common_names$source)
if ("eol" %in% sources) {
  for (s in sources[sources != "eol"]) {
    dt <- data.table(
      taxonID = eol_id,
      vernacularName = common_names[source == s, search_name],
      source = common_names[source == s, url],
      language = common_names[source == s, language],
      locality = NA,
      countryCode = NA,
      isPreferredName = tolower(common_names[source == s, preferred]),
      taxonRemarks = common_names[source == s, paste0("Google search results (", search_string, "): ", search_results, " total / ", subset_search_results, " after subsetting.")]
    )
    dir.create(paste0("~/desktop/", s), showWarnings = FALSE)
    write.table(dt, paste0("~/desktop/", s, "/common names.txt"), row.names = FALSE, na = "", sep = "\t", quote = FALSE)
  }
}

## Falling Fruit (future)
# ff_id | name | language | country | wikipedia_url | ...

# id:
# scientific_name:
# scientific_synonyms:
# locales: {
#   en: {
#     name:
#     synonyms:
#     wikipedia_url:
#   },
#   en-US: { ... },
#   en-BR: { ... },
#   de: {
#     wikipedia_url:
#   },
#   de-CH: { ... },
# }

dt_names <- common_names[order(-subset_search_results), .(n = unique(subset_search_results)), by = .(search_name, language)][, .(name = search_name[1], synonyms = list(search_name[-1])), by = language]
dt_wikipedia_urls <- common_names[source == "wikipedia", .(url = unique(url)), by = language]
dt <- merge(dt_names, dt_wikipedia_urls, by = "language")
# locales <- apply(dt, 1, function(x) {
#   list(names = x$search_names, wikipedia_url = x$url)
# })
# names(locales) <- dt$language
locales <- dt[, .(locale = list(list(name = name, synonyms = ifelse(is.empty(unlist(synonyms)), NA, unlist(synonyms)), wikipedia_url = url))), by = language]$locale
names(locales) <- dt$language
scientific_names[, .(n = length(unique(source))), by = name][n == max(n), name]
locales <- list(id = ff_id, scientific_name = preferred_scientific_name, scientific_synonyms = scientific_names[name != preferred_scientific_name, name], locales = locales)
# scientific_names[, .(n = length(unique(source))), by = name][n == max(n), name]
locales <- replace_values_in_list(locales, list(NA, character(0)), NULL)
