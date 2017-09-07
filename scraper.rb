#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'scraperwiki'
require 'nokogiri'
require 'colorize'
require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_list(url)
  noko = noko_for(url)
  noko.xpath('//h2[span[@id="Modifiche_Intervenute"]]/following-sibling::*').map(&:remove)

  h2 = noko.xpath('//h2[span[@id="Gruppi_Parlamentari"]]')
  h3s = h2.xpath('following-sibling::h2 | following-sibling::h3').slice_before { |e| e.name != 'h3' }.first
  h3s.first.xpath('following-sibling::ul/li').each do |li|
    who = li.css('a').first
    data = {
      name:     who.text.tidy,
      wikiname: who.attr('class') == 'new' ? nil : who.attr('title'),
      faction:  li.xpath('preceding::h3').last.css('span.mw-headline').text,
      source:   url,
    }
    puts data.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h if ENV['MORPH_DEBUG']
    ScraperWiki.save_sqlite(%i[name faction], data)
  end
end

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
scrape_list('https://it.wikipedia.org/wiki/Deputati_della_XVII_Legislatura_della_Repubblica_Italiana')
