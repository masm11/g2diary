#!/usr/bin/env ruby

require 'set'

class G2DiaryIndex
  INDEX_FILE = ENV['G2_INDEX_FILE'] || './index.g2'

  def initialize(make_new)
    @index = make_new ? {} : load
  end

  def load
    File.open(INDEX_FILE) do |f|
      Marshal.load(f)
    end
  end

  def save
    new_path = "#{INDEX_FILE}.new"
    File.open(new_path, "w") do |f|
      Marshal.dump(@index, f)
    end
    begin
      File.unlink(INDEX_FILE)
    rescue Errno::ENOENT
    end
    File.rename(new_path, INDEX_FILE)
  end

  def string_to_bigram(str)
    kws = {}

    str.each_char do |c|
      next if c =~ /\s/    # 空白文字だったら無視
      c.downcase!
      kws[c] = true
    end

    (0...str.length-1).each do |i|
      cc = str[i, 2]
      next if cc =~ /\s/    # 空白文字を含んでたら無視
      cc.downcase!
      kws[cc] = true
    end

    kws
  end

  def add_file(path)
    data = File.read(path)
    string_to_bigram(data).each do |kw, _|
      @index[kw] ||= Set.new
      @index[kw] << path
    end
  end

  def remove_file(path)
    @index.each do |kw, paths|
      paths.delete(path)
    end
  end

  def paths_of(kw)
    @index[kw].dup || Set.new
  end

  def search(str)
    kws = string_to_bigram(str)
    paths = paths_of(kws.keys.first)
    kws.each do |kw, _|
      paths = paths.intersection(paths_of(kw))
    end
    str.downcase!
    paths.select! do |path|
      data = File.read(path)
      data.include? str
    end
    paths
  end

  def all_docs
    r = Set.new
    @index.each do |_, paths|
      r = r.union(paths)
    end
    r
  end
end
