# Falling Fruit ------

Taxonomic_ranks <- c("Polyphyletic", "Kingdom", "Phylum", "Class", "Order", "Family", "Genus", "Multispecies", "Species", "Subspecies")
Categories <- c("forager", "freegan", "honeybee", "grafter")

# Clusters --------

Earth_radius = 6378137 # meters
Earth_circumference = 2 * pi * Earth_radius

# Translations ------

Language_codes <- as.data.table(read.csv('data/language_codes.csv', stringsAsFactors = FALSE, na.strings = ""))
Language_codes <- Language_codes[!(type %in% c("ancient", "historical"))]
# https://developers.google.com/custom-search/json-api/v1/overview
Google_cs_languages <- c("ar", "bg", "ca", "cs", "da", "de", "el", "en", "es", "et", "fi", "fr", "hr", "hu", "id", "is", "it", "iw", "ja", "ko", "lt", "lv", "nl", "no", "pl", "pt", "ro", "ru", "sk", "sl", "sr", "sv", "tr", "zh-cn", "zh-tw")
