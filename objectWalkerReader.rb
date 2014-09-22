#!/usr/bin/env ruby

require 'optparse'

options = {:list => false, :filename => nil, :timestamp => nil}

parser = OptionParser.new do|opts|
	opts.banner = "Usage: objectWalkerReader.rb [options]"
	opts.on('-l', '--list', 'list objectWalker dumps in the file') do
		options[:list] = true;
	end
	opts.on('-f', '--file filename', 'Full file path to automation.log (if not /var/www/miq/vmdb/log/automtion.log)') do |filename|
		options[:filename] = filename;
	end
	opts.on('-t', '--timestamp timestamp', 'Date/time of the objectWalker dump to be listed (hint: copy from -l output)') do |timestamp|
		options[:timestamp] = timestamp;
	end
	opts.on('-h', '--help', 'Displays Help') do
		puts opts
		exit
	end
end
parser.parse!

if options[:timestamp] && options[:list]
  puts "The options -t and -l shoud not be used together: use -l to list the dumps in the log file, and -t to select a particular dump timestamp"
  exit!
end

objectwalkerstart_re = /----\] I, \[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}) .*objectWalker \d{1,}\.\d{1,} - EVM Automate Method Started/
objectwalker_re = /.*(AEMethod objectwalker|Defined Method)\> (.*)/

dump_start = 0

if options[:filename].nil?
  filename = "/var/www/miq/vmdb/log/automation.log"
else
  filename = options[:filename]
end

begin
  file = File.new(filename, "r")
rescue => err
  puts "Error opening log file: #{err}"
  exit!
end
  
file.each do |line|
  match = objectwalkerstart_re.match(line)
  if match
    if options[:list]
      puts "Found objectWalker dump at #{match[1]}"
    end
    if options[:timestamp]
      if options[:timestamp] == match[1]
        dump_start = file.pos - line.length
        break
      end
    end
    #
    # Default is to dump the last objectWalker run
    #
    dump_start = file.pos - line.length
  end
end
unless options[:list]
  file.seek(dump_start)
  file.each do |line|
    match = objectwalker_re.match(line)
    if match
      puts match[2]
    end
    if ( line =~ /objectWalker - EVM Automate Method Ended/ )
      break
    end
  end
end
file.close
