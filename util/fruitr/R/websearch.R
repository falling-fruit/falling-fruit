#' Count Google Custom Search (CS) Results
#'
#' Free up to 100/day. Maximum 10,000/day. Rate limit 1/s. See https://developers.google.com/custom-search/json-api/v1/overview.
#'
#' @export
#' @family web search functions
#' @examples
#' count_google_cs_results("'Malus domestica'+'Apfel'", "en")
#' count_google_cs_results("'Malus domestica'+'Apfel'", "de")
count_google_cs_results = function(string, language = NULL, pause = FALSE) {
  if (pause) {
    Sys.sleep(1.1)
  }
  url <- parse_url("https://www.googleapis.com/customsearch/v1")
  query <- list(key = "AIzaSyDm7gTRTOlOIsum_KOwfM-X13RYexMW41M", cx = "017771660208863495094:7npb6irvsc0", q = string)
  if (!is.empty(language)) {
    if (!(language %in% Google_cs_languages)) {
      warning("Ignored unsupported language (", language, ").")
    } else {
      query <- c(query, lr = paste0("lang_", language))
    }
  }
  json <- content(GET(url, query = query))
  if (is.list(json) && !is.null(json$queries$request[[1]]$totalResults)) {
    return(as.integer(json$queries$request[[1]]$totalResults))
  }
}

#' Count Gigablast Search Results (DEPRECATED)
#'
#' Free. No quota is specified, but requests are often blocked. See https://gigablast.com/api.html
#'
#' @export
#' @family web search functions
#' @examples
#' count_gigablast_results("'Malus domestica'+'Apfel'")
count_gigablast_results = function(string) {
  url <- parse_url("http://www.gigablast.com/search")
  query <- list(format = "json", q = string)
  xml <- content(GET(url, query = query))
  json_path <- gsub(".*url='\\/([^']*)'.*", "\\1", getNodeSet(xml, "/html/body/@onload")[[1]])
  json <- content(GET(url, path = json_path))
  if (is.list(json) && !is.null(json$hits)) {
    return(json$hits)
  }
}
