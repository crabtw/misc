#!/usr/bin/env ruby

require 'optparse'

def nat_ord s
  s.split(/(\d+)|(\D+)/).select {|c| c != ''}.map do |c|
    x = c.to_i
    x > 0 || c[0] == '0' ? x : c
  end
end

class Fixnum
  alias :old_cmp :<=>
  def <=> a
    case a
      when Fixnum then old_cmp a
      when String then -1
    end
  end
end

class String
  alias :old_cmp :<=>
  def <=> a
    case a
      when String then old_cmp a
      when Fixnum then 1
    end
  end
end

if __FILE__ == $0
  i = 1
  len = Math.log10(ARGV.size) + 1
  dryrun = false

  OptionParser.new do |opts|
    opts.on('-s', '--start N', Integer, 'Start number (default 1)') {|v| i = v}
    opts.on('-l', '--len N', Integer, 'Minimal length (default log10(number of file))') {|v| len = v}
    opts.on('-d', '--dryrun', 'Don\'t rename files') {dryrun = true}
  end.parse!

  ARGV.sort_by {|f| nat_ord f}.each do |old|
    ext = File.extname old
    new = i.to_s.rjust(len, '0')

    new << '_' while File.exist?(new + ext)
    new += ext

    puts "#{old} => #{new}"
    File.rename(old, new) unless dryrun

    i += 1
  end
end
