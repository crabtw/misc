#!/usr/bin/ruby

def nat_ord s
  s.split(/([^0-9]?)(\d*)/).select {|c| c != ''}.map do |c|
    x = c.to_i
    x > 0 || c[0] == '0' ? x : c
  end
end

exit if ARGV.length < 1

dir = File.dirname ARGV.first
file = File.basename ARGV.first

Dir.chdir dir
all = Dir.entries(dir).select do |f|
  f =~ /\.(jpe?g|png|bmp|gif)$/i
end.sort_by {|f| nat_ord f}

exec 'feh', '--start-at', file, '-F', '-Y', *all
