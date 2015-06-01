#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'date'
require 'open-uri'
require 'date'
require 'csv'

# require 'colorize'
# require 'pry'
# require 'csv'
# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'

def noko_for(url)
  Nokogiri::HTML(open(url).read) 
end

def unbracket(str)
  cap = str.match(/^(.*?)\s*\((.*?)\)\s*$/) or return [str, '']
  return cap.captures 
end

def scrape_list(url)
  noko = noko_for(url)
  count = 0
  noko.css('div.content table tr').each do |row|
    tds = row.css('td')
    mp_url = URI.join(url, tds[1].at_css('a/@href').text).to_s
    mp_noko = noko_for(mp_url)
    data = { 
      id: mp_url.split('/').last.sub('.aspx',''),
      name: tds[1].css('a').text.strip,
      constituency: tds[0].text.strip,
      party: unbracket(tds[1].text.gsub(/[[:space:]]/, ' ').strip).last,
      executive: tds[2].text.strip,
      email: mp_noko.at_css('div.content a[href*=mailto]/@href').to_s.gsub(/[[:space:]]/, ' ').strip.sub('mailto:',''),
      term: 2012,
      source: mp_url,
    }
    data[:party_id] = data[:party]
    data[:constituency].sub!(/ C\*?$/, ' Central')
    data[:executive] = '' if data[:executive] == 'Backbencher'
    puts data
    ScraperWiki.save_sqlite([:id, :term], data)
    count += 1
  end
  puts "Added #{count}"
end

term = {
  id: 2012,
  name: '2012–',
  start_date: '2012-12-17',
}
ScraperWiki.save_sqlite([:id], term, 'terms')

scrape_list('http://www.parliament.bm/Members_of_Parliament.aspx')

