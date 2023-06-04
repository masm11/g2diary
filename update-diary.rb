#!/usr/bin/env ruby

require 'fileutils'
require_relative 'g2_diary_index'

Dir.chdir 'diary'

system('unset GIT_DIR; git pull origin master')

Dir.chdir '..'

last_stamp = Time.at(0)
begin
  last_stamp = File.mtime('stamp')
rescue
end

File.open('stamp.new', 'w', 0644) do |file|
  file.write(Time.now.to_s)
end

index = G2DiaryIndex.new(false)

FileUtils.mkdir_p('split')

Dir.glob("diary/*/*.td").sort.each do |path|
  stamp = File.mtime(path)
  next if stamp < last_stamp
  
  if path =~ /^diary\/\d{6}\/((\d{4})(\d{2})(\d{2}))\.td$/
    date = $1.to_i
    year = $2.to_i
    month = $3.to_i
    day = $4.to_i
    
    if date < 20190816
      next
    end

    if date >= 20140723
      enc = 'UTF-8'
    else
      enc = 'EUC-JIS-2004'	# EUC-JISX0213
    end
    
    if date >= 20150720
      style = 'GFM'
    else
      style = 'etDiary'
    end
    
    sections = []
    File.open(path, "r:#{enc}:utf-8") do |file|
      if style == 'GFM'
        in_pre = false
        file.each_line do |line|
          if !in_pre && line =~ /^#\s+(.*)\s*$/
            sections << { title: $1, body: [], }
          else
            in_pre = !in_pre if line =~ /^```/
            sections[sections.length - 1][:body] << line if sections.length >= 1
          end
        end
      else
        file.each_line do |line|
          if line =~ /^<<(.*)>>\s*$/
            sections << { title: $1, body: [], }
          else
            sections[sections.length - 1][:body] << line if sections.length >= 1
          end
        end
      end
    end
    
    FileUtils.mkdir_p('split/%04d%02d' % [year, month])
    
    Dir.glob('split/%04d%02d/%08dp*.est' % [year, month, date]).each do |spath|
      index.remove_file spath
    end
    FileUtils.rm(Dir.glob('split/%04d%02d/%08dp*.est' % [year, month, date]))
    
    sect_no = 0
    sections.each do |sect|
      sect_no += 1
      spath = 'split/%04d%02d/%08dp%02d.est' % [year, month, date, sect_no]
      File.open(spath, 'w') do |file|
        file.print "#{sect[:title]}\n"
        sect[:body].each do |line|
          file.print line
        end
      end
      index.add_file spath
    end
    
  end
end

index.save
File.rename('stamp.new', 'stamp')
