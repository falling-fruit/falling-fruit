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

#' Get Wiki Page from API
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
    return(list(source = type, date = response$date, url = response$url, status_code = response$status_code, json = json))
  }
}

#' Get Any Page from URL
#'
#' @export
#' @family Wiki functions
#' @examples
#' str(get_page("https://en.wikipedia.org/wiki/Malus_domestica"))
get_page <- function(url, content_only = TRUE) {
  response <- GET(url)
  parsed_content <- content(response)
  if (content_only) {
    return(parsed_content)
  } else {
    temp <- list(date = response$date, url = response$url, status_code = response$status_code, content = parsed_content)
    if ("xml_document" %in% class(parsed_content)) {
      names(temp)[4] <- "xml"
    } else if (is.list(parsed_content)) {
      names(temp)[4] <- "json"
    }
    return(temp)
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

#' Parse Wikipedia Common Names
#'
#' @family Wiki functions
#' @export
#' @examples
#' xml <- get_page("https://en.wikipedia.org/wiki/Malus_domestica")
#' parse_wikipedia_common_names(xml)
#' xml <- get_page("https://en.wikipedia.org/wiki/Abelmoschus")
#' parse_wikipedia_common_names(xml) # no names
parse_wikipedia_common_names <- function(xml, language = parse_wiki_url(xml_attr(xml_find_one(xml, xpath = "//link[@rel='canonical']"), "href"))[[1]]) {
  names_xml <- list(
    #first_regular_heading = xml_find_all(xml, xpath = "//h1[@id='firstHeading'][not(i)]"),
    first_regular_bolds = xml_find_all(xml, xpath = "//div[@id='mw-content-text']/p[position() < 3]//b[not(parent::*[self::i]) and not(i)]"),
    regular_biotabox_header <- xml_find_all(xml, xpath = "(//table[contains(@class, 'infobox biota')]//th)[1][not(i)]")
  )
  names <- unique(unlist(sapply(names_xml, xml_text)))
  common_names <- lapply(names, function(name) { list(name = name, language = language) })
  return(common_names)
}

# Wikimedia ----------------

#' Parse Wikimedia Commons Common Names
#'
#' @family Wiki functions
#' @export
#' @examples
#' xml <- get_page("https://commons.wikimedia.org/wiki/Malus_domestica")
#' parse_wikicommons_common_names(xml)
#' xml <- get_page("https://en.wikipedia.org/wiki/Abelmoschus")
#' parse_wikicommons_common_names(xml) # no names
parse_wikicommons_common_names = function(xml) {
  ## XML formats:
  # <bdi class="vernacular" lang="en"><a href="">name</a></bdi>
  # <bdi class="vernacular" lang="en">name</bdi>
  ## Name formats:
  # name1 / name2
  # name1, name2
  # name (category)
  vernacular_html <- xml_find_all(xml, xpath = "//bdi[@class='vernacular']")
  common_names <- lapply(vernacular_html, function(x) {
    attributes <- xml_attrs(x)
    language <- attributes[["lang"]]
    name <- trimws(gsub("[ ]*\\(.*\\)", "", xml_text(x)))
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
#' xml <- get_page("https://species.wikimedia.org/wiki/Malus_domestica")
#' parse_wikispecies_common_names(xml)
#' xml <- get_page("https://en.wikipedia.org/wiki/Abelmoschus")
#' parse_wikispecies_common_names(xml) # no names
parse_wikispecies_common_names <- function(xml) {
  # XML formats:
  # <b>language:</b>&nbsp;[name|<a>name</a>]
  # Name formats:
  # name1, name2
  vernacular_html <- xml_find_all(xml, xpath = "(//h2/span[@id='Vernacular_names']/parent::*/following-sibling::div)[1]")
  languages_html <- xml_find_all(vernacular_html, xpath = "b")
  languages <- gsub("\\s*:\\s*", "", sapply(languages_html, xml_text))
  names_html <- xml_find_all(vernacular_html, xpath = "b[not(following-sibling::*[1][self::a])]/following-sibling::text()[1] | b/following-sibling::*[1][self::a]/text()")
  names <- gsub("^\\s*", "", sapply(names_html, xml_text))
  common_names <- mapply(list, name = names, language = languages, SIMPLIFY = FALSE, USE.NAMES = FALSE)
  return(common_names)
}
