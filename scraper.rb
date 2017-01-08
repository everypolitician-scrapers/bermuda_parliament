#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'
require 'scraped_page_archive/open-uri'

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def unbracket(str)
  cap = str.match(/^(.*?)\s*\((.*?)\)\s*$/) or return [str, 'Independent']
  cap.captures
end

def scrape_list(url)
  noko = noko_for(url)
  count = 0
  noko.css('div.content table tr').each do |row|
    tds = row.css('td')
    mp_url = URI.join(url, tds[1].at_css('a/@href').text).to_s
    mp_noko = noko_for(mp_url)
    data = {
      id:        mp_url.split('/').last.sub('.aspx', ''),
      name:      tds[1].css('a').text.tidy,
      area:      tds[0].text.tidy,
      party:     unbracket(tds[1].text.gsub(/[[:space:]]/, ' ').tidy).last,
      executive: tds[2].text.tidy,
      email:     mp_noko.at_css('div.content a[href*=mailto]/@href').to_s.gsub(/[[:space:]]/, ' ').tidy.sub('mailto:', ''),
      term:      2012,
      image:     mp_noko.css('li.PBItem div.content h1').xpath('./following::img[1]/@src').text,
      source:    mp_url,
    }
    data[:party_id] = data[:party]
    data[:area].sub!(/ C\*?$/, ' Central')
    data[:area_id], data[:area] = data[:area].split(' - ', 2) if data[:area][/ - /]
    data[:executive] = '' if data[:executive] == 'Backbencher'
    # sigh http://stackoverflow.com/questions/13013987/ruby-how-to-escape-url-with-square-brackets-and
    data[:image] = URI.join(mp_url, URI.encode(URI.decode(data[:image])).gsub('[', '%5B').gsub(']', '%5D')).to_s unless data[:image].to_s.empty?
    ScraperWiki.save_sqlite(%i(id term), data)
    count += 1
  end
  puts "Added #{count}"
end

ScraperWiki.sqliteexecute('DELETE FROM data') rescue nil
scrape_list('http://www.parliament.bm/Members_of_Parliament.aspx')
