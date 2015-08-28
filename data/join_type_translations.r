#install.packages(c("RCurl", "RJSONIO"))
library(RCurl)
library(RJSONIO)

# Parameters
lang <- "it"

# Load translations
eol <- read.csv('eol_names.csv', stringsAsFactors = FALSE, na.strings = '')
wiki <- read.csv('wikipedia_names.csv', stringsAsFactors = FALSE, na.strings = '')

# Filter by language, Remove empty entries
eol <- eol[eol$language == lang & !is.na(eol$eol_names), ]
wiki <- wiki[wiki$language == lang & !is.na(wiki$wiki_names), ]

# Join tables
temp <- merge(eol, wiki, all = TRUE)

# Sort by ff_scientific, then ff_name
temp <- temp[order(temp$ff_scientific, temp$ff_name), ]

# Initialize columns
temp[, 'translated_name'] <- NA

# Choose the "best" name?
for (i in 1:nrow(temp)) {
  print(paste0(temp$ff_name[i], ' [', temp$ff_scientific[i], ']'))
  
  # Build list of names
  names <- unique(strsplit(paste(na.omit(c(temp$eol_names[i], temp$wiki_names[i]))[1], sep = ','), ',')[[1]])
  names <- gsub("^\\s+|\\s+$", "", names)
  scientific_name <- temp$ff_scientific[i]
  # Skip name if same as scientific?
  
  #names = unique(strsplit("fagiolo comune, fagiolo, fagiolo dall'occhio", ', ')[[1]])
  #scientific_name <- "Vigna unguiculata subsp. unguiculata"
  
  # Choose "best" name
  if (length(names) == -1) {
    # If only one, choose it
    temp$translated_name[i] = names[1]
  } else if (!is.na(scientific_name)) {
    # Otherwise, use search engine to determine which name is most commonly used.
    # FIXME: Quickly reaches maximum quota. Need to find a very cheap or free alternative with higher quotas.
    google_results <- rep(NA, length(names))
    for (j in 1:length(names)) {
      query <- curlEscape(sprintf("\"%s\"+\"%s\"", names[j], scientific_name))
      result <- fromJSON(getURL(paste0("https://ajax.googleapis.com/ajax/services/search/web?v=1.0&q=", query), .opts = list(ssl.verifypeer = FALSE)))
      google_results[j] <- as.integer(result$responseData$cursor$estimatedResultCount)
      Sys.sleep(1)
    }
    if (max(google_results) > 0) {
      names[which(google_results == max(google_results))]
    #  temp$translated_name[i] <- names[which(google_results == max(google_results))]
    }
  }
  #cbind(names, google_results)
}

# Export
write.csv(temp, paste(lang, "_names_pending.csv", sep = ""), row.names = FALSE, na = "")