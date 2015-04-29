# Parameters
lang = "pt"

# Load translations
eol = read.csv('eol_names.csv', stringsAsFactors = FALSE, na.strings = '')
wiki = read.csv('wikipedia_names.csv', stringsAsFactors = FALSE, na.strings = '')

# Filter
eol = eol[!is.na(eol$eol_names) & eol$language == lang, ]
wiki = wiki[wiki$language == lang & !is.na(wiki$wiki_url) & wiki$ambiguous == 0, ]

# Join tables
temp = merge(eol, wiki, all = TRUE)

# Ignore rank: 0, 7
#temp = temp[is.na(temp$ff_rank) | !(temp$ff_rank == 0 | temp$ff_rank == 7), ]

# Automatic algorithm to guess the "best" name?

# Export
write.csv(temp, paste(lang, "_names_pending.csv", sep = ""), row.names = FALSE, na = "")