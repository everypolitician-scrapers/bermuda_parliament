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

class MembersPage < Scraped::HTML
  decorator Scraped::Response::Decorator::AbsoluteUrls

  field :members do
    noko.css('div.content table tr').map do |row|
      fragment row => MemberRow
    end
  end
end

class MemberRow < Scraped::HTML
  field :id do
    source.split('/').last.sub('.aspx', '')
  end

  field :name do
    tds[1].css('a').text.tidy
  end

  field :area do
    tds[0].text.tidy.sub(/ C\*?$/, ' Central').split(' - ').last
  end

  field :area_id do
    tds[0].text.split(' - ').first.tidy
  end

  field :party_id do
    unbracket(tds[1].text.tidy).last
  end

  field :party do
    party_id
  end

  field :executive do
    exec = tds[2].text.tidy
    return '' if exec == 'Backbencher'
    exec
  end

  field :source do
    tds[1].at_css('a/@href').text
  end

  private

  def tds
    noko.css('td')
  end

  def unbracket(str)
    cap = str.match(/^(.*?)\s*\((.*?)\)\s*$/) or return [str, 'Independent']
    cap.captures
  end
end

class MemberPage < Scraped::HTML
  decorator Scraped::Response::Decorator::AbsoluteUrls

  field :email do
    noko.at_css('div.content a[href*=mailto]/@href').to_s.gsub(/[[:space:]]/, ' ').tidy.sub('mailto:', '')
  end

  field :image do
    noko.css('li.PBItem div.content h1').xpath('./following::img[1]/@src').text
  end
end

def scrape(h)
  url, klass = h.to_a.first
  klass.new(response: Scraped::Request.new(url: url).response)
end

start = 'http://www.parliament.bm/Members_of_Parliament.aspx'
data = scrape(start => MembersPage).members.map do |mem|
  mem.to_h.merge(scrape(mem.source => MemberPage).to_h).merge(term: 2012)
end
# puts data.map { |r| r.sort_by { |k, _| k }.to_h }

ScraperWiki.sqliteexecute('DELETE FROM data') rescue nil
ScraperWiki.save_sqlite(%i(id term), data)
puts "Added #{data.count}"
