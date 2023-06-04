#!/usr/bin/env ruby

require_relative 'g2_diary_index'

case ARGV[0]
when '--init'
  idx = G2DiaryIndex.new(true)
  idx.save
when '--add'
  idx = G2DiaryIndex.new(false)
  ARGV[1..-1].each do |path|
    idx.add_file(path)
  end
  idx.save
when '--remove'
  idx = G2DiaryIndex.new(false)
  ARGV[1..-1].each do |path|
    idx.remove_file(path)
  end
  idx.save
when '--search'
  idx = G2DiaryIndex.new(false)
  puts idx.search([ARGV[1]])
end
