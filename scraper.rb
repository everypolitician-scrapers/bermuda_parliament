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
    source.split('/').last.to_s.sub('.aspx', '')
  end

  field :name do
    name_and_party.first
  end

  field :area do
    tds[0].text.tidy.sub(/ C\*?$/, ' Central').split(' - ').last
  end

  field :area_id do
    tds[0].text.split(' - ').first.tidy
  end

  field :party_id do
    name_and_party.last
  end

  field :party do
    name_and_party.last
  end

  field :executive do
    exec = tds[2].text.tidy
    return '' if exec == 'Backbencher'
    exec
  end

  field :source do
    tds[1].css('a/@href').text
  end

  private

  def tds
    noko.css('td')
  end

  def name_and_party
    text = tds[1].text.tidy
    match = text.match(/(.*?) \((.*)\)/) or return [text, 'Independent']
    match.captures
  end
end

class MemberPage < Scraped::HTML
  decorator Scraped::Response::Decorator::AbsoluteUrls

  field :email do
    # See https://github.com/everypolitician/scraped/issues/57
    noko.at_css('div.content a[href*=mailto]/@href').to_s.sub('%C2%A0','').gsub('%20','').sub('mailto:', '').tidy
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
  member_page = mem.source.empty? ? {} : scrape(mem.source => MemberPage).to_h
  mem.to_h.merge(member_page).merge(term: 2012)
end
# puts data.map { |r| r.sort_by { |k, _| k }.to_h }

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
ScraperWiki.save_sqlite(%i(id term), data)
puts "Added #{data.count}"
