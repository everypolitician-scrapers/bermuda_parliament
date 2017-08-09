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
  decorator Scraped::Response::Decorator::CleanUrls

  field :members do
    noko.css('div.content table tr').map do |row|
      fragment row => MemberRow
    end
  end
end

class MemberRow < Scraped::HTML
  TITLES = ['Colonel', 'Lt.', 'Col'].freeze

  field :id do
    return name.tr(' ', '_') if source.to_s.empty?
    source.split('/').last.to_s.sub('.aspx', '').tidy
  end

  field :name do
    prefixed_name.last.join(' ')
  end

  field :honorific_prefix do
    prefixed_name.first.join(' ')
  end

  field :area do
    tds[0].text.tidy.sub(/ C\*?$/, ' Central').split(' - ').last
  end

  field :area_id do
    tds[0].text.split(' - ').first.tidy
  end

  field :party_id do
    party
  end

  field :party do
    party_str = name_and_party.last
    return party_str unless party_str.to_s.empty?
    # Scott Simmons has no party on the site currently, but is PLP:
    #   https://elections.gov.bm/elections/results/electionresult/315.html
    return 'PLP' if name == 'Scott Simmons'
    return 'Independent'
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
    match = text.match(/(.*?) \((.*)\)/) or return [text, nil]
    match.captures
  end

  def name_parts
    name_and_party.first.split(' ').compact.map(&:tidy)
  end

  def prefixed_name
    name_parts.partition { |part| TITLES.include? part }
  end
end

class MemberPage < Scraped::HTML
  decorator Scraped::Response::Decorator::CleanUrls

  field :email do
    # See https://github.com/everypolitician/scraped/issues/57
    noko.at_css('div.content a[href*=mailto]/@href').to_s.sub('%C2%A0', '').gsub('%20', '').sub('mailto:', '').tidy
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
  mem.to_h.merge(member_page).merge(term: 2017)
end
data.each { |mem| puts mem.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
ScraperWiki.save_sqlite(%i[id term], data)
puts "Added #{data.count}"
