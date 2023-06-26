#!/usr/bin/env ruby

require 'erb'
require 'webrick'
require_relative 'g2_diary_index'
require_relative 'g2_grep'

MAX_BODY_CHARS = 256
MAX_BODY_CHARS_FOR_XS = 150
MAX_ITEMS = 25

def truncate(str, len)
  if str.length > len
    "#{str[0...len]}..."
  else
    str
  end
end

def error(res, code, msg)
  File.open('error.html.erb') do |f|
    @msg = msg
    erb = ERB.new f.read
    res.body = erb.result
    res['Content-Type'] = 'text/html'
    res.status = code
  end
end

def handle(req, res)
  if req.request_method != 'GET'
    res.status = 404
    return
  end

  url_prefix = ENV['TDIARY_URL'] || 'http://mike/tdiary'
  @search_url = ENV['SEARCH_URL'] || 'http://localhost:8005/'

  query = req.query
  @q = (query['q'] || '').force_encoding('UTF-8')
  @page = (query['page'] || 1).to_i

  if @q =~ /\A\s*\z/
    error(res, 400, '検索語句を入力してください')
    return
  end
  
  if @q.length >= 64
    error(res, 400, '検索語句が長すぎます')
    return
  end

  idx = G2DiaryIndex.new(false)
  grep = G2Grep.new(@q)
  paths = grep.parsed do |snt|
    snt.nil? ? idx.all_docs : idx.search(snt)
  end
  paths = paths.to_a.sort.reverse

  @total_nr_items = paths.length
  @nr_pages = (@total_nr_items + MAX_ITEMS - 1) / MAX_ITEMS

  @page_begin = (@page - 1) * MAX_ITEMS
  @page_end = [@page_begin + MAX_ITEMS, @total_nr_items].min

  paths = paths[@page_begin...@page_end] || []
  @items = []
  paths.each do |path|
    if path =~ %r|.*/((\d{4})(\d{2})(\d{2}))p(\d{2})\.[a-z0-9]+$|
      h = {
        date:    "#{$2}-#{$3}-#{$4}",
        url:     "#{url_prefix}?date=#{$1}#p#{$5}",
        title:   '',
        body:    '',
        body_xs: '',
      }

      File.open(path) do |f|
        h[:title] = f.readline(chomp: true)
        text = f.read.sub(/\s+/, ' ')
        h[:body] = truncate(text, MAX_BODY_CHARS)
        h[:body_xs] = truncate(text, MAX_BODY_CHARS_FOR_XS)
      end

      @items << h
    end
  end

  File.open('g2diary.html.erb') do |f|
    erb = ERB.new f.read
    res.body = erb.result
    res['Content-Type'] = 'text/html'
  end
rescue Exception => e
  puts e.to_s
  puts e.message
  puts e.backtrace.join("\n")
  error(res, 500, "内部エラーです")
end

srv = WEBrick::HTTPServer.new(BindAddress: '127.0.0.1', Port: 8005)
srv.mount_proc('/') do |req, res|
  handle req, res
end
srv.start
