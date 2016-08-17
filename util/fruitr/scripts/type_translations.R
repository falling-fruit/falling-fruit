#### Collect data --------------
# output_dir <- "~/sites/falling-fruit-data/fruitr/"
# dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Single type test
ff_types <- get_ff_types(urls = TRUE)
ff_id = 2546
ff_type <- ff_types[id == ff_id]
responses <- query_sources_about_type(ff_type)

# Aggregate common names
common_name_lists <- lapply(responses, function(response) {
  temp <- eval(parse(text = paste0("parse_", response$source, "_common_names(response$", ifelse(is.null(response$xml), "json", "xml"), ")")))
  if (length(temp) > 0) {
    return(mapply(c, source = response$source, temp, SIMPLIFY = FALSE, USE.NAMES = FALSE))
  } else {
    return(NULL)
  }
})
common_names <- rbindlist(lapply(common_name_lists, rbindlist), fill = TRUE)

# Normalize languages
# sapply(common_names$language, normalize_language)
codes <- c("ISO639.1", "ISO639.2B", "ISO639.2T", "ISO639.3", "ISO639.6", "ISO639.3_macro", "wikipedia")
common_names$language <- sapply(common_names$language, function(language) {
  count <- sum(sapply(codes, function(code) {
    any(!is.na(Language_codes[[code]]) & Language_codes[[code]] == language)
  }))
  if (count == 0) {
    normalize_language(language, types = setdiff(names(Language_codes), codes))
  } else {
    normalize_language(language, types = codes)
  }
})

# Filter names
# TODO: filter source name tables?
common_names <- common_names[!(name %in% ff_type$scientific_names)] # remove if matches any scientific name
# TODO: Repeated names?

# Search names
# TODO: No scientific name?
common_names[, google_cs_results := count_google_cs_results(paste0("\"", ff_type$scientific_names[1], "\"+\"", name, "\""), intersect(language, Google_cs_languages)), by = 1:nrow(common_names)]

# Rank names
# TODO: language and google_language (or forget about searching by language?)
# TODO: run subsetting and ranking for each language seperately, leave original search results intact
google_cs_results <- common_names$google_cs_results
# If same or subset of scientific name, NA search results
# TODO: Skip search for same_as_scientific
same_as_scientific <- sapply(paste0("(^| )", common_names$name, "($| )"), grepl, x = ff_type$scientific_names[1], ignore.case = TRUE)
google_cs_results[same_as_scientific] <- NA
# TODO: Run baseline search with just scientific name, and convert results as fractions of all results?

# If subset of other names, difference search results
# [test] Pine: 20, Blue pine: 17, White blue pine: 10, White: 20 => 3, 7, 10, 10
# x <- c("Pine", "Blue pine", "White blue pine", "White")
# google_results <- c(20, 17, 10, 20)
# [test] Pine: 20, Blue pine: 17, Blue pine a: 10, Blue pine b: 5, Blue pine b c: 1 => 3, 2, 10, 4, 1
# x <- c("Pine", "Blue pine", "Blue pine a", "Blue pine b", "Blue pine b c")
# google_results <- c(20, 17, 10, 5, 1)
# [test] Pine: 20, Blue: 15, Blue pine: 10, Pine blue: 3 => 7, 2, 10, 3
# x <- c("Pine", "Blue", "Blue pine", "Pine blue")
# google_results <- c(20, 15, 10, 3)
subsets <- do.call("rbind", lapply(paste0(common_names$name, " | ", common_names$name), grepl, x = common_names$name, ignore.case = TRUE))
# Go in order of least to most children, most to least parents
n_children <- rowSums(subsets)
n_parents <- colSums(subsets)
node_sequence <- seq_len(length(common_names$name))[order(n_children, -n_parents)]
for (node in node_sequence) {
  # skip leaf nodes (children == 0)
  if (n_children[node] > 0) {
    is_child <- subsets[node, ]
    google_cs_results[node] <- google_cs_results[node] - sum(google_cs_results[is_child])
  }
}
common_names$google_cs_results <- google_cs_results

# TODO: Rank by multiple sources
# TODO: Rank by preferred

# Response list to table
dt <- rbindlist(lapply(responses, "[", c("source", "date", "url", "status_code")), fill = TRUE)
dt[, xml := sapply(responses, "[", "xml")]
dt[, json := sapply(responses, "[", "json")]
dt[, id := ff_id]









#saveRDS(responses, file = paste0(output_dir, ff_types$id[i], ".rds"))
#saveRDS(ff_types, file = paste0(output_dir, "ff_types-queries.rds"))

####
# Parse responses

for (i in seq_len(nrow(ff_types))) {
  for (j in seq_len(length(ff_types$queries[[i]]))) {
    query <- ff_types$queries[[i]][[j]]
    if (!is.null(query)) {
      type <- query$type
      ff_types$queries[[i]][[j]]$parse <-
        switch(type,
               eol = parse_eol_page(query),
               col = parse_col_page(query),
               wikipedia = parse_wikipedia_page(query),
               wikicommons = parse_wikicommons_page(query)
        )
    }
  }
}

saveRDS(ff_types, file = paste0(output_dir, "ff_types-parse.rds"))

####
# Collapse common names

ff_types$common_names = list(NULL)
for (i in seq_len(nrow(ff_types))) {
  common_name_lists <- lapply(ff_types$queries[[i]], function(query) {
    if (length(query$parse$common_names) > 0) {
      df <- list_to_dataframe(query$parse$common_names)
      df$source <- query$type
      return(df)
    }
  })
  common_name_df <- do.call("rbind.fill", common_name_lists)
  if (!is.null(common_name_df)) {
    # remove forbidden characters (allow letters, single spaces, ', and -)
    common_name_df$name <- gsub("[^\\p{L}\\p{Nd} \\'\\-]|[0-9]", "", common_name_df$name, perl = TRUE)
    common_name_df$name <- gsub("[ ]+", " ", common_name_df$name, perl = TRUE)
    # group duplicates (ignore case)
    common_name_df$name <- tolower(common_name_df$name)
    #common_names <- group_dataframe_by_columns(common_name_df, "name")
    #names(common_names)[names(common_names) == "language"] = "languages"
    ff_types$common_names[[i]] <- common_name_df
  }
}

saveRDS(ff_types, file = paste0(output_dir, "ff_types-names.rds"))

#################
## Choose names
output_dir <- "~/sites/falling-fruit-data/names/"

####
# Search common names
language <- "el"
google_cs_language <- NULL
if (any(Google_cs_languages %in% language)) {
  google_cs_language <- language
}

# Count names
#total_names <- sum(unlist(sapply(ff_types$common_names, nrow)))
#total_languages <- length(unique(unlist(sapply(ff_types$common_names, function(x) {x$languages} ))))
#total_types <- nrow(ff_types)
n_names <- sapply(ff_types$common_names, function(common_names) {
  n <- sum(unlist(common_names$languages) == language)
  ifelse(is.na(n), 0, n)
})
sum(n_names) # names
sum(n_names[n_names > 1]) # names that need ranking
sum(n_names > 0) # types with names

# Search names
have_names <- which(n_names > 0)
have_multiple_names <- which(n_names > 1)
for (i_type in have_multiple_names) {

  # Initialize column only if doesn't already exist
  df <- ff_types$common_names[[i_type]]
  if (!("search" %in% names(df))) {
    df$search <- list(NULL)
  }

  # Run searches (only as needed)
  scientific_name <- ff_types$scientific_name[i_type]
  have_language <- which(sapply(df$languages, function(languages) {
    any(languages %in% language)
  }))
  for (i_name in have_language) {
    common_name <- df$name[i_name]
    if (is.na(scientific_name)) {
      search_string <- paste0("\"", common_name, "\"")
    } else {
      search_string <- paste0("\"", scientific_name, "\"+\"", common_name, "\"")
    }
    print(search_string)
    is_new_search <- any(is.null(df$search[[i_name]]$string), search_string != df$search[[i_name]]$string)
    is_updated <- FALSE
    if (is_new_search) {
      search <- list()
      search$string <- search_string
      search$google_cs_results <- count_google_cs_results(search$string, language = google_cs_language)
      search$gigablast_results <- count_gigablast_results(search$string)
      search$date <- Sys.time()
      df$search[[i_name]] <- search
      is_updated <- TRUE
    } else {
      if (is.null(df$search[[i_name]]$google_cs_results)) {
        df$search[[i_name]]$google_cs_results <- count_google_cs_results(search_string, language = google_cs_language)
        is_updated <- TRUE
      }
      if (is.null(df$search[[i_name]]$gigablast_results)) {
        df$search[[i_name]]$gigablast_results <- count_gigablast_results(search_string)
        is_updated <- TRUE
      }
      if (is_updated) {
        df$search[[i_name]]$date <- Sys.time()
      }
    }
    print(paste(df$search[[i_name]]$google_cs_results,
                df$search[[i_name]]$gigablast_results,
                sep = ", "))
    if (is.null(df$search[[i_name]]$gigablast_results)) {
      warning("Gigablast quota exceeded!")
    }
    if (is.null(df$search[[i_name]]$google_cs_results)) {
      warning("Google Custom Search quota exceeded!")
    }
    if (is_updated) {
      ff_types$common_names[[i_type]] <- df
      Sys.sleep(1)
    }
  }
}

saveRDS(ff_types, file = paste0(output_dir, "ff_types-search.rds"))

####
# Evaluate common names
# id | language | taxonomic_rank | scientific_name | en_name | en_wikipedia_url | wikipedia_url | names

# Initialize
name_table <- data.frame(
  id = ff_types$id,
  language = language,
  categories <- sapply(ff_types$category_mask, function(x) { paste(expand_category_mask(x), collapse = ", ") } ),
  taxonomic_rank = ff_types$taxonomic_rank,
  scientific_name = ff_types$scientific_name,
  en_name = ff_types$name,
  en_wikipedia_url = ff_types$wikipedia_url,
  wikipedia_url = NA,
  names = NA,
  robot_choice = NA,
  human_choice = NA,
  stringsAsFactors = FALSE
)

# Process common names
for (i_type in seq_len(nrow(ff_types))) {

  # Initialize
  df <- ff_types$common_names[[i_type]]

  # Wikipedia url
  wikipedia_url <- unlist(sapply(ff_types$queries[[i_type]], function(query) {
    if (!is.null(query) && query$type == "wikipedia") {
      sapply(query$parse$pages, function(page) {
        if (page$language == language) {
          page$url
        }
      })
    }
  }))
  name_table$wikipedia_url[i_type] <- ifelse(is.null(wikipedia_url), NA, wikipedia_url)

  # Skip if no names for language
  if (n_names[i_type] == 0) {
    next
  }

  # Filter by language
  language_filter <- sapply(df$languages, function(languages) {language %in% languages} )
  df <- df[language_filter, ]

  # Skip if < 2 names for language
  if (n_names[i_type] == 1) {
    name_table$names[i_type] <- df$name
    name_table$robot_choice[i_type] <- df$name
    next
  }

  # Get search results
  google_cs_results <- sapply(df$search, function(search) {
    ifelse(is.null(search$google_cs_results), NA, search$google_cs_results)
  })
  gigablast_results <- sapply(df$search, function(search) {
    ifelse(is.null(search$gigablast_results), NA, search$gigablast_results)
  })

  # If same or subset of scientific name, zero search results
  same_as_scientific <- sapply(paste0("(^| )", df$name, "($| )"), grepl, x = ff_types$scientific_name[i_type], ignore.case = TRUE)
  google_cs_results[same_as_scientific] <- 0
  gigablast_results[same_as_scientific] <- 0

  # If subset of other names, difference search results
  # [test] Pine: 20, Blue pine: 17, White blue pine: 10, White: 20 => 3, 7, 10, 10
  # x <- c("Pine", "Blue pine", "White blue pine", "White")
  # google_results <- c(20, 17, 10, 20)
  # [test] Pine: 20, Blue pine: 17, Blue pine a: 10, Blue pine b: 5, Blue pine b c: 1 => 3, 2, 10, 4, 1
  # x <- c("Pine", "Blue pine", "Blue pine a", "Blue pine b", "Blue pine b c")
  # google_results <- c(20, 17, 10, 5, 1)
  # [test] Pine: 20, Blue: 15, Blue pine: 10, Pine blue: 3 => 7, 2, 10, 3
  # x <- c("Pine", "Blue", "Blue pine", "Pine blue")
  # google_results <- c(20, 15, 10, 3)
  subsets <- do.call("rbind", lapply(paste0(df$name, " | ", df$name), grepl, x = df$name, ignore.case = TRUE))
  # Go in order of least to most children, most to least parents
  n_children <- rowSums(subsets)
  n_parents <- colSums(subsets)
  node_sequence <- seq_len(length(df$name))[order(n_children, -n_parents)]
  for (node in node_sequence) {
    # skip leaf nodes (children == 0)
    if (n_children[node] > 0) {
      is_child <- subsets[node, ]
      google_cs_results[node] <- google_cs_results[node] - sum(google_cs_results[is_child])
      gigablast_results[node] <- gigablast_results[node] - sum(gigablast_results[is_child])
    }
  }

  # Prepare filters
  preferred_filter <- sapply(df$preferred, function(preferred) {TRUE %in% preferred} )
  multisource_filter <- sapply(df$sources, function(sources) {length(sources)} )

  # Rank names
  name_order <- order(rank(rowMeans(cbind(
    rank(google_cs_results),
    rank(gigablast_results),
    rank(multisource_filter)
  ))), decreasing = TRUE)
  name_table$names[i_type] <- paste(df$name[name_order], collapse = ", ")
  name_table$robot_choice[i_type] <- df$name[name_order][1]
}

# Export names table
saveRDS(name_table, file = paste0(output_dir, language, "_names_pending.rds"))
write.csv(name_table, file = paste0(output_dir, language, "_names_pending.csv"), row.names = FALSE, na = "")

####
#### NEW names table (en_GB)

types <- load_types(urls = TRUE)
types$categories <- sapply(types$category_mask, function(x) { paste(expand_category_mask(x), collapse = ", ") })
name_table <- types[order(scientific_name, taxonomic_rank_order, name), .(id, language = "en", categories, taxonomic_rank, scientific_name, wikipedia_url, en_names = ifelse(is.na(synonyms), name, paste(name, synonyms, sep = ", ")), en_GB = "", en_IE = "")]
write.csv(name_table, file = "~/desktop/en_GB_names_pending.csv", row.names = FALSE, na = "")
