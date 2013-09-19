#!/usr/bin/ruby

exit if ARGV.length < 1

dir = File.dirname ARGV.first
file = File.basename ARGV.first

Dir.chdir dir
all = Dir.entries(dir).select do |f|
  f =~ /\.(jpe?g|png|bmp|gif)$/i
end.sort

exec 'feh', '--start-at', file, '-F', '-Y', *all
