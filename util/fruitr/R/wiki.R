# Wiki ----------------

#' Parse Wiki URL
#'
#' @export
#' @family Wiki functions
#' @examples
#' parse_wiki_url("https://en.wikipedia.org/wiki/Malus_domestica")
parse_wiki_url <- function(url) {
  matches <- str_match(url, "//([^\\.]+).([^\\.]+).[^/]*/wiki/([^\\?]+)")
  return(list(
    wiki = matches[2],
    type = matches[3],
    page = matches[4]
  ))
}

#' Build Wiki URL
#'
#' @export
#' @family Wiki functions
#' @examples
#' build_wiki_url("en", "wikipedia", "Malus domestica")
#' build_wiki_url("commons", "wikimedia", "Malus domestica")
#' build_wiki_url("species", "wikimedia", "Malus domestica")
build_wiki_url <- function(wiki, type, page) {
  return(paste0("https://", wiki, ".", type, ".org/wiki/", gsub(" ", "_", page)))
}

#' Get Wiki Page
#'
#' @export
#' @family Wiki functions
#' @examples
#' str(get_wiki_page("en", "wikipedia", "Malus domestica"))
get_wiki_page <- function(wiki, type, page, content_only = TRUE) {
  url <- parse_url(paste0("https://", wiki, ".", type, ".org/w/api.php"))
  query <- list(format = "json", action = "parse", redirects = TRUE, page = gsub(" ", "_", page))
  response <- GET(url, query = query)
  json <- content(response)
  if (!is.list(json) || length(json$parse) == 0) {
    json <- NULL
  } else {
    json <- json$parse
  }
  if (content_only) {
    return(json)
  } else {
    response$content <- json
    return(response)
  }
}

# Wikipedia ----------------

#' Parse Wikipedia Language Links
#'
#' @family Wiki functions
#' @export
#' @examples
#' json <- get_wiki_page("en", "wikipedia", "Malus domestica")
#' parse_wikipedia_langlinks(json)
parse_wikipedia_langlinks <- function(json) {
  langlinks <- lapply(json$langlinks, function(x) {
    list(
      language = x$lang,
      url = x$url
    )
  })
  return(langlinks)
}

#' Parse Wikipedia Names
#'
#' @family Wiki functions
#' @export
#' @examples
#' xml <- content(GET("https://en.wikipedia.org/wiki/Malus_domestica"))
#' parse_wikipedia_names(xml)
parse_wikipedia_names <- function(xml) {
  first_heading <- xpathApply(xml, path = "//h1[@id='firstHeading']")
  first_regular_bolds <- xpathApply(xml, path = "//div[@id='mw-content-text']/p[position() < 3]//b[not(parent::*[self::i]) and not(i)]")
  first_italic_bolds <- xpathApply(xml, path = "//div[@id='mw-content-text']/p[position() < 3]//b[parent::*[self::i] or i]")
  biotabox_header <- xpathApply(xml, path = "//table[contains(@class, 'infobox biota')]//th[1][not(i)]")
  names <- sapply(c(first_heading, first_regular_bolds, first_italic_bolds, biotabox_header), xmlValue)
  # names <- unique(unlist(strsplit(names, "[ ]*,[ ]*")))
  # names <- gsub("\\.|\\n|\\t|\\?|[ ]*\\(.*\\)|\"", "", names)
  # names <- trimws(names)
  return(names)
}

# Wikimedia ----------------

#' Parse Wikimedia Commons Common Names
#'
#' @family Wiki functions
#' @export
#' @examples
#' xml <- content(GET("https://commons.wikimedia.org/wiki/Malus_domestica"))
#' parse_wikicommons_common_names(xml)
parse_wikicommons_common_names = function(xml) {
  ## XML formats:
  # <bdi class="vernacular" lang="en"><a href="">name</a></bdi>
  # <bdi class="vernacular" lang="en">name</bdi>
  ## Name formats:
  # name1 / name2
  # name1, name2
  # name (category)
  vernacular_html <- xpathApply(xml, path = "//bdi[@class='vernacular']")
  common_names <- lapply(vernacular_html, function(x) {
    attributes <- xmlAttrs(x)
    language <- attributes[["lang"]]
    name <- trimws(gsub("[ ]*\\(.*\\)", "", xmlValue(x)))
    list(
      name = name,
      language = language
    )
  })
  return(common_names)
}

#' Parse Wikispecies Common Names
#'
#' @family Wiki functions
#' @export
#' @examples
#' xml <- content(GET("https://species.wikimedia.org/wiki/Malus_domestica"))
#' parse_wikispecies_common_names(xml)
parse_wikispecies_common_names <- function(xml) {
  # XML formats:
  # <b>language:</b>&nbsp;[name|<a>name</a>]
  # Name formats:
  # name1, name2
  vernacular_html <- xpathApply(xml, path = "//h2/span[@id='Vernacular_names']/parent::*/following-sibling::div[1]")[[1]]
  languages_html <- xpathApply(vernacular_html, path = "b")
  languages <- sapply(gsub("\\s*:\\s*", "", sapply(languages_html, xmlValue)), normalize_language, USE.NAMES = FALSE)
  names_html <- xpathApply(vernacular_html, path = "b[not(following-sibling::*[1][self::a])]/following-sibling::text()[1] | b/following-sibling::*[1][self::a]/text()")
  names <- trimws(sapply(names_html, xmlValue))
  common_names <- mapply(list, name = names, language = languages, SIMPLIFY = FALSE, USE.NAMES = FALSE)
  return(common_names)
}
