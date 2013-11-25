#!/usr/bin/env ruby

require 'optparse'

def nat_ord s
  s.split(/([^0-9]?)(\d*)/).select {|c| c != ''}.map do |c|
    x = c.to_i
    x > 0 || c[0] == '0' ? x : c
  end
end

i = 1

OptionParser.new do |opts|
  opts.on('-s', '--start N', Integer, 'Start number (default 1)') do |v|
    i = v
  end
end.parse!

MIN_LEN = Math.log10(ARGV.size) + 1

ARGV.sort_by {|f| nat_ord f}.each do |old|
  ext = File.extname old
  new = i.to_s.rjust(MIN_LEN, '0')

  new << '_' while File.exist?(new + ext)
  new += ext

  puts "#{old} => #{new}"
  File.rename(old, new)

  i += 1
end
