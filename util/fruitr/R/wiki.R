# Wiki ----------------

#' Parse Wiki URL
#'
#' @export
#' @family Wiki functions
#' @examples
#' parse_wiki_url("https://en.wikipedia.org/wiki/Malus_domestica")
parse_wiki_url <- function(url, api = FALSE) {
  if (!is.empty(url) && grepl("/w/api.php?", url)) {
    matches <- stringr::str_match(url, "//([^\\.]+).([^\\.]+).[^/]*/w/api\\.php\\?.*page=([^&]+).*$")
  } else {
    matches <- stringr::str_match(url, "//([^\\.]+).([^\\.]+).[^/]*/wiki/([^\\?]+)")
  }
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
build_wiki_url <- function(wiki, type, page, url = NULL) {
  if (!is.null(url)) {
    wiki <- url$wiki
    type <- url$type
    page <- url$page
  }
  return(paste0("https://", wiki, ".", type, ".org/wiki/", gsub(" ", "_", page)))
}

#' Get Wiki Page from API
#'
#' @export
#' @family Wiki functions
#' @examples
#' str(content(get_wiki_page("https://en.wikipedia.org/wiki/Malus_domestica")))
get_wiki_page <- function(url, format = "json", action = "parse", redirects = TRUE) {
  url <- RCurl::curlUnescape(url)
  params <- parse_wiki_url(url)
  url <- parse_url(paste0("https://", params$wiki, ".", params$type, ".org/w/api.php"))
  query <- c(page = params$page, mget(c("format", "action", "redirects")))
  return(GET(url, query = query[sapply(query, "!=", "")]))
}

# Wikipedia ----------------

#' Parse Wikipedia Page
#'
#' @family Wiki functions
#' @export
#' @examples
#' pg <- get_wiki_page("https://en.wikipedia.org/wiki/Malus_domestica")
#' str(parse_wikipedia_page(pg))
#' pg <- get_wiki_page("https://en.wikipedia.org/wiki/Abelmoschus")
#' str(parse_wikipedia_page(pg)) # no names
parse_wikipedia_page <- function(page, types = c("common_names", "langlinks")) {
  result <- list()
  json <- jsonlite::fromJSON(rawToChar(page$content), simplifyVector = FALSE)
  if (is.null(json$parse)) {
    return(result)
  }
  ## Language links
  if ("langlinks" %in% types) {
    langlinks <- lapply(json$parse$langlinks, function(x) {
      list(
        language = x$lang,
        url = x$url
      )
    })
    result$langlinks <- langlinks
  }
  ## Common names
  if ("common_names" %in% types) {
    xml <- xml2::read_html(json$parse$text[[1]])
    language = stringr::str_match(page$url, 'http[s]*://([^\\.]*)\\.')[, 2]
    names_xml <- list(
      regular_bolds = xml_find_all(xml, xpath = "/html/body/p[count(preceding::div[contains(@id, 'toc') or contains(@class, 'toc')]) = 0 and count(preceding::h1) = 0 and count(preceding::h2) = 0 and count(preceding::h3) = 0]//b[not(parent::*[self::i]) and not(i)]"),
      regular_biotabox_header = xml_find_all(xml, xpath = "(//table[contains(@class, 'infobox biota') or contains(@class, 'infobox_v2 biota')]//th)[1]/b[not(parent::*[self::i]) and not(i)]")
    )
    regular_title <- na.omit(str_match(json$parse$displaytitle, "^([^<]*)$")[, 2]) # Often unreliable
    names <- unique(c(unlist(sapply(names_xml, xml_text)), regular_title))
    common_names <- lapply(names, function(name) {list(name = name, language = language)})
    result$common_names <- common_names
  }
  ## Return
  return(result)
}

# Wikimedia ----------------

#' Parse Wikimedia Commons Page
#'
#' @family Wiki functions
#' @export
#' @examples
#' pg <- get_wiki_page("https://commons.wikimedia.org/wiki/Malus_domestica")
#' str(parse_wikicommons_page(pg))
#' pg <- get_wiki_page("https://commons.wikimedia.org/wiki/Abelmoschus")
#' str(parse_wikicommons_page(pg)) # no names
parse_wikicommons_page = function(page, types = c("common_names")) {
  result <- list()
  json <- jsonlite::fromJSON(rawToChar(page$content), simplifyVector = FALSE)
  if (is.null(json$parse)) {
    return(result)
  }
  ## Common names
  if ("common_names" %in% types) {
    xml <- read_html(json$parse$text[[1]])
    vernacular_html <- xml_find_all(xml, xpath = "//bdi[@class='vernacular']")
    # XML formats:
    # <bdi class="vernacular" lang="en"><a href="">name</a></bdi>
    # <bdi class="vernacular" lang="en">name</bdi>
    ## Name formats:
    # name1 / name2
    # name1, name2
    # name (category)
    common_names <- lapply(vernacular_html, function(x) {
      attributes <- xml_attrs(x)
      language <- attributes[["lang"]]
      name <- trimws(gsub("[ ]*\\(.*\\)", "", xml_text(x)))
      list(
        name = name,
        language = language
      )
    })
    result$common_names <- common_names
  }
  ## Return
  return(result)
}

#' Parse Wikispecies Page
#'
#' @family Wiki functions
#' @export
#' @examples
#' pg <- get_wiki_page("https://species.wikimedia.org/wiki/Malus_domestica")
#' str(parse_wikispecies_page(pg))
#' pg <- get_wiki_page("https://species.wikimedia.org/wiki/Abelmoschus")
#' str(parse_wikispecies_page(pg)) # no names
parse_wikispecies_page <- function(page, types = c("common_names")) {
  result <- list()
  json <- jsonlite::fromJSON(rawToChar(page$content), simplifyVector = FALSE)
  if (is.null(json$parse)) {
    return(result)
  }
  ## Common names
  if ("common_names" %in% types) {
    xml <- read_html(json$parse$text[[1]])
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
    result$common_names <- common_names
  }
  ## Return
  return(result)
}
