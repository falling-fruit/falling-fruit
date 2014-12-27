#!/usr/bin/env ruby

require 'rubygems'
require 'open-uri'
require 'json'
require 'nokogiri'

en_title = "Malus pumila"
url = "http://en.wikipedia.org/w/api.php?format=json&action=parse&redirects&page=" + en_title.gsub(" ","%20")
page = JSON.parse(open(url).read)
if (page.has_key?("parse") and page["parse"].has_key?("title"))
  en_title = page["parse"]["title"]
  en_url = "https://en.wikipedia.org/wiki/" + page["parse"]["title"]

  # Extract common names
  content = Nokogiri::HTML(page["parse"]["text"].to_s)
  puts content.css('body > p > b')
  puts content.css("table[class='infobox'][class='biota']")
  if (content.css("table[class='infobox biota'] th")[0])
    puts content.css("table[class='infobox biota'] th")[0].text
  end
  
end
