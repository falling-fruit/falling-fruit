## TODO: Validate common name language based on unicode characters used
# For each language: compile exemplar characters (http://unicode.org/repos/cldr-tmp/trunk/diff/by_type/misc.exemplarCharacters.html)
# See also:
# http://www.unicode.org/repos/cldr/trunk/common/supplemental/supplementalData.xml
# http://www.unicode.org/Public/UCD/latest/ucd/Scripts.txt
# https://github.com/dsc/guess-language/blob/master/guess_language/Blocks.txt
# http://www.unicode.org/cldr/charts/latest/supplemental/index.html
# https://github.com/kent37/guess-language/blob/master/guess_language/guess_language.py
# https://github.com/MangoTheCat/franc/blob/master/inst/data.json
# http://unicode.org/cldr/trac/browser/trunk/common/main/fr.xml
## TODO: Migrate to using taxize
# https://github.com/ropensci/taxize
## TODO: Contribute to taxize for wikis
# https://github.com/ropenscilabs/wikitaxa
# https://github.com/ropensci/taxize/issues/317

# devtools::load_all()
library(fruitr)
library(data.table)
library(splitstackshape)

# Initialize
output_dir <- "~/sites/falling-fruit-data/fruitr/"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
ff_types <- get_ff_types(urls = TRUE)

#### Collect data ####
# responses: httr::response (+ source)
# scientific_names: source | url | name | rank | preferred | ff_preferred
# common_names: source | url | name | language | language_code | country | preferred | ff_preferred | search_string | search_results | subset_search_results

# Query sources for new types
parse = FALSE
for (ff_id in ff_types[pending == FALSE, id]) {

  # Fetch type
  ff_type <- ff_types[id == ff_id]
  cat(paste0(build_type_strings(ff_type$id, ff_type$name, ff_type$scientific_name), " => "))
  responses_loaded <- FALSE
  scientific_names_loaded <- FALSE

  # Collect, parse, and save data
  response_file <- paste0(output_dir, ff_id, "_responses.rds")
  if (!file.exists(response_file)) {
    cat("[responses] ")
    responses <- query_sources_about_type(ff_type)
    responses <- parse_sources_about_type(responses)
    saveRDS(responses, response_file)
    Sys.sleep(1) # avoids throttling APIs
    responses_loaded <- TRUE
  } else if (parse) {
    cat("[parse] ")
    responses <- readRDS(response_file)
    responses <- parse_sources_about_type(responses)
    saveRDS(responses, response_file)
    responses_loaded <- TRUE
  }

  # Parse scientific names
  scientific_name_file <- paste0(output_dir, ff_id, "_scientific_names.rds")
  if (!file.exists(scientific_name_file)) {
    cat("[scientific_names] ")
    if (!responses_loaded) {
      responses <- readRDS(response_file)
      responses_loaded <- TRUE
    }
    scientific_names <- build_scientific_name_table(responses, ff_type)
    saveRDS(scientific_names, scientific_name_file)
    scientific_names_loaded <- TRUE
  }

  # Parse common names
  common_name_file <- paste0(output_dir, ff_id, "_common_names.rds")
  if (!file.exists(common_name_file)) {
    cat("[common_names] ")
    if (!responses_loaded) {
      responses <- readRDS(response_file)
      responses_loaded <- TRUE
    }
    if (!scientific_names_loaded) {
      scientific_names <- readRDS(scientific_name_file)
    }
    common_names <- build_common_name_table(responses, scientific_names, normalize_languages = FALSE, search = FALSE)
    saveRDS(common_names, common_name_file)
  }

  cat("\n")
}

#### Scientific names - Compile ####

files <- list.files(output_dir, "*_scientific_names")
tables <- list()
for (file in files) {
  dt <- readRDS(paste0(output_dir, file))
  if (length(dt) > 0) {
    dt[, ff_id := as.numeric(regmatches(file, regexpr("^[0-9]+", file)))]
    tables[[length(tables) + 1]] <- dt
    cat(".")
  } else {
    cat("o")
  }
}
scientific_names <- rbindlist(tables, fill = TRUE)

##### Common names - Compile ####

files <- list.files(output_dir, "*_common_names")
tables <- list()
for (file in files) {
  dt <- readRDS(paste0(output_dir, file))
  if (length(dt) > 0) {
    dt[, ff_id := as.numeric(regmatches(file, regexpr("^[0-9]+", file)))]
    tables[[length(tables) + 1]] <- dt
    cat(".")
  } else {
    cat("o")
  }
}
common_names <- rbindlist(tables, fill = TRUE)

##### Common names - Clean ####

common_names[, is_valid := TRUE]
# sort(table(regmatches(common_names$name, regexpr("[[:punct:]]{1}", common_names$name))), decreasing = TRUE)
# sort(table(regmatches(common_names$name[common_names$is_valid], regexpr("[[:punct:]]{1}", common_names$name[common_names$is_valid]))), decreasing = TRUE)
# print(common_names[grepl("\\.", name) & is_valid == TRUE, .(source, substr(name, 0, 30), substr(url, 0, 80), ff_id, language)], nrows = 20)

# Allow:
# -
# '
# ’
# ‘
# · [ca, pcd, zh-min-nan]
# ་ [bo]
# 、[ja, zh-hant, zh, yue]
# ・[ja]
# ־ [he, yi]
# ʹ [kk-tr, kk-latn]
# ། [bo]
# । [sa]
# ′
# ´

pre_split_invalids <- list(
  list("&[a-z#x0-9]*;", ignore.case = TRUE) # html escaped characters
)
for (i in seq_along(pre_split_invalids)) {
  common_names[do.call(grepl, c(pre_split_invalids[[i]], list(x = name))), is_valid := FALSE]
}
delimiters <- "[,，،;&|‖/]" # WARNING: less commonly, '/' used to specify different choices for part of name (e.g. castanhier/-nhèr, èrba dels/dei/aus/delh/deth jesuitas/jesuista)
common_names <- rbindlist(list(common_names[is_valid == FALSE, ], cSplit(common_names[is_valid == TRUE, ], "name", delimiters, direction = "long", fixed = FALSE, type.convert = FALSE)))
common_names[, name := clean_strings(name)]
substitutions <- list(
  # UTF-8 Debugging
  # http://www.i18nqa.com/debug/utf8-debug.html
  list("Ã¥", "å"),
  list("Ã¤", "ä"),
  list("Ã©", "é"),
  list("Ã¶", "ö"),
  list("_", " "),
  list(list("<b>(.*)</b>", "\\1", ignore.case = TRUE), quote(source == "eol")),
  list(list("\\? (.*) \\?", "\\1"), quote(source == "eol")),
  list("(.*)\\?$", "\\1"),
  list("\\(.*\\)", ""),
  list("（.*）", ""),
  list("\\[.*\\]", ""),
  list(list(" spp\\.$", ""), quote(source == "eol")),
  list(list("\\*$", ""), quote(source == "eol")),
  list("«(.*)»", "\\1"),
  list("„(.*)“", "\\1")
)
for (i in seq_along(substitutions)) {
  if (is.list(substitutions[[i]][[1]])) {
    common_names[do.call(grepl, c(substitutions[[i]][[1]][-2], list(x = name))) & eval(substitutions[[i]][[2]]), name := do.call(gsub, c(substitutions[[i]][[1]], list(x = name)))]
  } else {
    common_names[do.call(grepl, c(substitutions[[i]][-2], list(x = name))), name := do.call(gsub, c(substitutions[[i]], list(x = name)))]
  }
}
invalids <- list(
  list("(?=.*\\.)(?=(?!.*(St|Sto|Sta|S|Mt)\\. ))", perl = TRUE),
  list("[]0-9\\*\\+\\?\\|\\^\\$\\(\\)\\{\\}\\[,:;<>（），&×«»„“≠!#=¥—–：۔॥‖¶↓¤©~@/∙]"),
  list("\\", fixed = TRUE)
)
for (i in seq_along(invalids)) {
  common_names[do.call(grepl, c(invalids[[i]], list(x = name))), is_valid := FALSE]
}

##### Common names - Languages ####

# common_names[, language := original_language]
common_names[, original_language := language]
common_names[, language := tolower(language)]
delimiters <- "[,/]"
common_names <- cSplit(common_names, "language", delimiters, direction = "long", fixed = FALSE, type.convert = FALSE)
common_names[, language := clean_strings(language)]
substitutions <- list(
  list("\\s*name$", ""),
  list("\\s*dialect$", ""),
  list("\u200e", "")
)
for (i in seq_along(substitutions)) {
  common_names[do.call(grepl, c(substitutions[[i]][-2], list(x = language))), language := do.call(gsub, c(substitutions[[i]], list(x = language)))]
}
common_names[source == "wikipedia", language2 := normalize_language(language, "wikipedia"), by = language]
common_names[source == "wikicommons", language2 := normalize_language(language), by = language]
# 1: In normalize_language(language) : [no] Language found multiple times
# 2: In normalize_language(language) : [nrm] Language found multiple times
# 3: In normalize_language(language) : [als] Language found multiple times
common_names[source == "wikispecies", language2 := normalize_language(language), by = language]
# 2: In normalize_language(language) : [ދިވެހިބަސް] Language not recognized
# 4: In normalize_language(language) : [ᨅᨔ ᨕᨘᨁᨗ] Language not recognized
common_names[source == "eol", language2 := normalize_language(language), by = language]
# In normalize_language(language) : [no] Language found multiple times
common_names[source == "col", language2 := normalize_language(language), by = language]
# 5: In normalize_language(language) : [aboriginal] Language not recognized
# 6: In normalize_language(language) : [aleria piaguaje - inf] Language not recognized
# 7: In normalize_language(language) : [banda] Language found multiple times
# 8: In normalize_language(language) : [ib dialect?] Language not recognized
# 10: In normalize_language(language) : [m] Language not recognized
common_names[source == "inaturalist", language2 := normalize_language(language), by = language]
# 1: In normalize_language(language) : [vermont flora codes] Language not recognized
# 14: In normalize_language(language) : [yuto-nahua] Language not recognized
# 15: In normalize_language(language) : [unspecified] Language not recognized
# 21: In normalize_language(language) : [piñón de una hoja] Language not recognized
# 23: In normalize_language(language) : [parraleña] Language not recognized
common_names[is.na(language2) & grepl("^([^\\(]*) \\(.*\\)$", language), language2 := normalize_language(gsub("^([^\\(]*) \\(.*\\)$", "\\1", language)), by = language]
# In normalize_language(gsub("^([^\\(]*) \\(.*\\)$", "\\1", language)) : [informal latinized name] Language not recognized
# unique(common_names[is.na(language2), language])
# common_names[is.na(language2) & language == "nrm", source]
# Save results
common_names[, is_recognized_language := !is.na(language2)]
common_names[, language := language2]
common_names[is_recognized_language == FALSE, language := original_language]
common_names[, language2 := NULL]
common_names[is_scientific_name == TRUE | is_scientific_substring == TRUE, is_valid := FALSE]

# common_names[is_valid == TRUE & is_recognized_language == FALSE, .(count = .N), by = original_language][order(count, decreasing = TRUE)]
# print(common_names[is_valid == TRUE & is_recognized_language == TRUE, .(count = .N, original = list(unique(original_language))), by = language][order(count, decreasing = TRUE)], nrow = Inf)
# print(common_names[is_valid == TRUE & is_recognized_language == FALSE & original_language == "nrm", .(source, substr(name, 0, 50), ff_id, substr(url, 0, 100))], nrow = Inf)

##### Common names - Search ####

# TODO: Move up?
ff_types[, has_binomial_scientific_name := sapply(strsplit(ff_types$scientific_name, " "), length) == 2 & !grepl("'", scientific_name)]
ff_types[, has_canonical_scientific_name := !is.na(scientific_name) & !taxonomic_rank %in% c("Polyphyletic", "Multispecies") & !(taxonomic_rank == "Subspecies" && has_binomial_scientific_name)]

# NOTE: "-" equivalent to " " in Google Search
common_names[, search_name := tolower(gsub("-", " ", name))]
languages <- c("es", "el", "pl", "pt", "pt-br", "it", "fr", "de")
for (i in scientific_names[ff_id >= 963, sort(unique(ff_id))]) {
  if (ff_types[id == i, has_canonical_scientific_name]) {
    print(paste0(build_type_strings(ff_types[id == i, id], ff_types[id == i, name], ff_types[id == i, scientific_name])))
    preferred_scientific_name <- scientific_names[ff_id == i & ff_preferred == TRUE, unique(name)]
    # Skip duplicate name-language pairs
    # Skip if only one name for that language
    common_names[is_valid == TRUE & ff_id == i, search_string := paste0("'", preferred_scientific_name, "'+'", search_name, "'"), by = search_name]
    selected_languages <- common_names[is_valid == TRUE & ff_id == i & language %in% languages,  .(n = .N), by = language][n > 1, language]
    common_names[is_valid == TRUE & ff_id == i & language %in% selected_languages & is.na(search_results), search_results := count_google_cs_results(search_string, language, pause = TRUE), by = .(search_string, language)]
    # Subset results by language
    common_names[is_valid == TRUE & ff_id == i & language %in% selected_languages, subset_search_results := subset_search_results(search_name, search_results), by = language]
  }
}
searches <- unique(common_names[!is.na(search_results), .(ff_id, language, search_string, search_results, subset_search_results, date = Sys.time())])
saveRDS(searches, paste0(output_dir, "searches.rds"))

#### Output ####

# Normalize common names
common_names[!is.na(search_results) & !is.na(display_name), display_name := normalize_common_name(x = name, x_search = search_name), by = .(language, search_name)]

## Falling Fruit (present)
# {locale}_names.csv
# ff_id | translated_name

languages <- c("es", "el", "pl", "pt", "pt-br", "it", "fr", "de")
for (lang in languages) {
  dt <- common_names[is_valid == TRUE & language == lang & !is.na(subset_search_results), .(n = unique(subset_search_results)), by = .(ff_id, display_name)][, .(translated_name = display_name[max(n) == n]), by = ff_id]
  write.csv(dt, paste0(output_dir, lang, "_names.csv"), row.names = FALSE)
}

## EOL
# common names.txt (by source, excluding eol)
# taxonID | vernacularName | source | language | locality | countryCode | isPreferredName | taxonRemarks

files <- list.files(output_dir, "*_responses.rds")
ff_ids <- as.numeric(regmatches(files, regexpr("^[0-9]+", files)))
eol_ids <- integer(length(files))
for (i in seq_along(files)) {
  r <- readRDS(paste0(output_dir, files[i]))
  is_eol <- which(sapply(r, "[", "source") == "eol")
  if (length(is_eol) == 1) {
    eol_ids[i] <- jsonlite::fromJSON(rawToChar(r[[is_eol]]$content))$identifier
    cat(".")
  } else {
    eol_ids[i] <- NA
    cat("o")
  }
}
dt <- merge(common_names, data.table(ff_id = ff_ids, eol_id = eol_ids), by = "ff_id")[!is.na(eol_id)]

sources <- unique(common_names$source)
for (s in sources[sources != "eol"]) {
  sdt <- dt[is_scientific_name == FALSE & is_scientific_substring == FALSE & is_valid == TRUE & is_recognized_language == TRUE & source == s, .(
    taxonID = eol_id,
    vernacularName = name,
    source = url,
    language,
    locality = NA,
    countryCode = ifelse(grepl("^[a-z]{2,3}\\-[a-z]{2}$", language), gsub("^[a-z]{2,3}\\-", "", language), NA),
    isPreferredName = tolower(preferred),
    taxonRemarks = paste0(
      paste0("Original language: '", original_language, "'. "),
      ifelse(!is.na(search_results), paste0("Google search results (", search_string, "): ", search_results, " total / ", subset_search_results, " after subsetting."), "")
    )
  )]
  dir.create(paste0(output_dir, "eol/", s), showWarnings = FALSE, recursive = TRUE)
  write.table(sdt, paste0(output_dir, "eol/", s, "/common names.txt"), row.names = FALSE, na = "", sep = "\t", quote = FALSE)
}

## Falling Fruit (future)
# ff_id | name | language | country | wikipedia_url | ...

# id:
# scientific_names:
# locales: {
#   en: {
#     names:
#     wikipedia_url:
#   },
#   en-US: { ... },
#   en-BR: { ... },
#   de: {
#     wikipedia_url:
#   },
#   de-CH: { ... },
# }

x <- scientific_names[, .(ff_preferred, n = length(unique(source))), by = .(ff_id, name, ff_preferred)][order(ff_id, -ff_preferred, -n)][, .(scientific_names = list(name)), by = ff_id]
y <- common_names[is_valid == TRUE & is_recognized_language == TRUE][order(-subset_search_results)][, display_name := ifelse(is.na(display_name), search_name, display_name)][, .(locale = list(list(names = display_name, wikipedia_url = ifelse(sum(source == "wikipedia") == 0, NA_character_, build_wiki_url(url = parse_wiki_url(unique(url[source == "wikipedia"]))))))), by = .(ff_id, language)][, .(locales = list(names, wikipedia_url)), by = ff_id]

y$locales <- apply(y, 1, function(yi) {
  temp <- list()
  temp[[yi$language]] <- list(names = yi$names, wikipedia_url = yi$wikipedia_url)
})
z <- merge(x, y, by = "ff_id")

dt_wikipedia_urls <- common_names[ff_id == i & is_valid == TRUE & is_recognized_language == TRUE & source == "wikipedia", .(url = build_wiki_url(url = parse_wiki_url(unique(url)))), by = language]



type_lists <- list()
for (i in ff_types[, id]) {
  t <- list(
    id = i,
    scientific_names = scientific_names[ff_id == i, .(ff_preferred, n = length(unique(source))), by = name][order(-ff_preferred), unique(name)]
  )
  if (nrow(common_names[ff_id == i & is_valid == TRUE & is_recognized_language == TRUE]) > 0) {
    dt_names <- common_names[ff_id == i & is_valid == TRUE & is_recognized_language == TRUE][order(-subset_search_results)][, .(results = unique(subset_search_results), display_name = ifelse(is.na(unique(display_name)), search_name, unique(display_name))), by = .(language, search_name)]
    dt_wikipedia_urls <- common_names[ff_id == i & is_valid == TRUE & is_recognized_language == TRUE & source == "wikipedia", .(url = build_wiki_url(url = parse_wiki_url(unique(url)))), by = language]
    dt <- merge(dt_names, dt_wikipedia_urls, by = "language")[order(-results)]
    locales <- dt[, .(locale = list(list(names = display_name, wikipedia_url = url))), by = .(language, url)]$locale
    names(locales) <- dt[, unique(language)]
    t$locales <- locales
    type_lists[[length(type_lists) + 1]] <- t
  }
}

