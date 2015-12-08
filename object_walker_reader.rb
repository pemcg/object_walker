#!/usr/bin/env ruby
#
# object_walker_reader - extract the latest (no arguments), or a selected object_walker dump from automation.log or other renamed or
# saved log file.
#
#Usage: object_walker_reader.rb [options]
#    -l, --list                       list object_walker dumps in the file
#    -f, --file filename              Full file path to automation.log (if not /var/www/miq/vmdb/log/automtion.log)
#    -t, --timestamp timestamp        Date/time of the object_walker dump to be listed (hint: copy from -l output)
#    -d, --diff timestamp1,timestamp2 Date/time of two object_walker dumps to be compared using 'diff'
#    -h, --help                       Displays Help
#
# Examples:
#
# ./object_walker_reader.rb -l
# Found object_walker dump at 2014-09-17T13:28:42.052043
# Found object_walker dump at 2014-09-17T13:34:52.649359
# Found object_walker dump at 2014-09-17T15:06:29.250086
# ...
# 
# ./object_walker_reader.rb -l -f /Documents/CloudForms/cf30-automation-log
# Found object_walker dump at 2014-09-18T09:52:28.797868
# Found object_walker dump at 2014-09-18T09:53:31.455892
# ...
# 
# ./object_walker_reader.rb -t 2014-09-18T09:44:27.146812
# object_walker 1.0 - EVM Automate Method Started
#      object_walker:   Dumping $evm.root
#      object_walker:   $evm.root.ae_provider_category = infrastructure   (type: String)
#      object_walker:   $evm.root.class = Methods   (type: String)
#      object_walker:   $evm.root.instance = object_walker   (type: String)
#      object_walker:   $evm.root['miq_server'] => # <MiqAeMethodService::MiqAeServiceMiqServer:0x00000008f242b8>   (type: DRb::DRbObject)
#      |    object_walker:   $evm.root['miq_server'].build = 20140822170824_3268809   (type: String)
#      |    object_walker:   $evm.root['miq_server'].capabilities = {:vixDisk=>true, :concurrent_miqproxies=>2}   (type: Hash)
#      |    object_walker:   $evm.root['miq_server'].cpu_time = 2312.0   (type: Float)
#      |    object_walker:   $evm.root['miq_server'].drb_uri = druby://127.0.0.1:50656   (type: String)
#      |    object_walker:   $evm.root['miq_server'].guid = 5132a574-3d76-11e4-9150-001a4aa80204   (type: String)
# ... 
#
# Author: Peter McGowan (pemcg@redhat.com)
#           Copyright 2014 Peter McGowan, Red Hat
#
# Revision History
#
# Original      1.0     18-Sep-2014
#               1.1     16-Feb-2015     Updated to change name change from objectWalker to object_walker
#               1.1-1   19-Feb-2015     Changed the object_walker_start_re regex to allow for maj.min-up
#               1.1-2   08-Feb-2015     Changed the regexes to search for 'objectWalker' or 'object_walker'
#               1.1-3   09-Feb-2015     Changed all the regexes this time
#               1.1-4   22-Mar-2015     Fixed the case where a requested timestamp that didn't exist would still dump the last object_walker output
#               1.1-5   09-May-2015     Read automation.log in UTF-8 format
#               1.2     11-May-2015     Re-factored, and added --diff switch
#               1.3     06-Oct-2015     Changed regexes to match pre or post 1.6 format object_walker dumps. No longer print 'object_walker'
#                                       for each line. Strip the ID from 1.6 format object_walker dumps.
#               1.4     02-Nov-2015     Print continuation lines where a value is multi-line
#               1.7     08-Dec-2015     Bumping version to match object_walker 1.7. We now handle the indentation string here
#  

require 'optparse'
require 'tempfile'

VERSION = "1.7"
@debug = false

valid_timestamp_re = /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}/
#
# Match 1.7 format object_walker dumps
#
@object_walker_start_re = %r{
                            ----\]\ I,\ \[(?<timestamp>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6})
                            \ .*[Oo]bject_*[Ww]alk.*?(?<id>\#\w+):\ \ \ (?<output>Object\ Walker\ (?<version>.+)\ Starting)
                          }x
@object_walker_body_re = %r{
                          .*AEMethod\ [Oo]bject_*[Ww]alk.*>\ [Oo]bject_*[Ww]alk.*?(?<id>\#\w+)*:
                          \[(?<indent_level>\d+)\]\ (?<output>.*)
                          |
                          .*ERROR.*AEMethod\ [Oo]bject_*[Ww]alk.*>\ [Oo]bject_*[Ww]alk.*?(?<id>\#\w+)*\ (?<output>.*)
                          |
                          (?<continuation_line>^[^\[].+$)
                          }x
@object_walker_end_re = %r{
                          [Oo]bject_*[Ww]alk.*?(?<id>\#\w+):\ \ \ (?<output>Object\ Walker\ Complete)
                          }x

#-------------------------------------------------------------------------------------------------------------
# Method:       list_dumps
# Purpose:      List all object_walker dumps found in a given file
# Arguments:    file: the opened automation file object
# Returns:      nothing
#-------------------------------------------------------------------------------------------------------------

def list_dumps(file)
  file.each do |line|
    match = @object_walker_start_re.match(line)
    if match
      puts "Found object_walker dump at #{match[:timestamp]}"
    end
  end
end

#-------------------------------------------------------------------------------------------------------------
# Method:       indent_level_to_string
# Purpose:      Converts an indentation level integer to the equivalent string
# Arguments:    indent_level - an integer
# Returns:      the string
#-------------------------------------------------------------------------------------------------------------

def indent_level_to_string(indent_level)
  base_indent = "     "
  return base_indent += "|    " * indent_level.to_i
end

#-------------------------------------------------------------------------------------------------------------
# Method:       find_dump
# Purpose:      Writes an object_walker dump to stdout or a temporary file
# Arguments:    file: the opened automation file object
#               timestamp: an optional timestamp to dump the output from
#               tempfile: an optional temp file to write the output to (used with --diff)
# Returns:      nothing
#-------------------------------------------------------------------------------------------------------------

def find_dump(file, timestamp=nil, tempfile=nil)
  found_timestamp = false
  dump_start = 0
  id = nil
  version = nil
  file.seek(0)
  file.each do |line|
    match = @object_walker_start_re.match(line)
    if match
      id = match[:id]
      version = match[:version]
      unless timestamp.nil?
        if timestamp == match[:timestamp]
          dump_start = file.pos - line.length
          found_timestamp = true
          break
        end
      end
      #
      # Default is to dump the last object_walker run
      #
      dump_start = file.pos - line.length
    end
  end
  unless timestamp.nil?
    unless found_timestamp
      raise "Timestamp: #{timestamp} not found in log file"
    end
  end
  #
  # Now rewind to the specified dump output and print the object_walker dump
  #
  file.seek(dump_start)
  indent_level = 0
  file.each do |line|
    match = @object_walker_start_re.match(line)
    if match
      if match[:id] == id
        if tempfile.nil?
          puts "#{match[:output]}"
        else
          tempfile.write("#{match[:output]}\n")
        end
      end
    end
    match = @object_walker_body_re.match(line)
    if match
      if match[:continuation_line]
        if tempfile.nil?
          puts "#{indent_level_to_string(indent_level)}#{line}"
        else
          tempfile.write("#{indent_level_to_string(indent_level)}#{line}\n")
        end
      elsif match[:id] == id
        if match[:indent_level]
          indent_level = match[:indent_level]
        end
        if tempfile.nil?
          puts "#{indent_level_to_string(indent_level)}#{match[:output]}"
        else
          tempfile.write("#{indent_level_to_string(indent_level)}#{match[:output]}\n")
        end
      end
    end
    match = @object_walker_end_re.match(line)
    if match
      if match[:id] == id
        if tempfile.nil?
          puts "#{match[:output]}"
        else
          tempfile.write("#{match[:output]}\n")
        end
        break
      end
    end
  end
end

#-------------------------------------------------------------------------------------------------------------
# Method:       diff_dumps
# Purpose:      Compares two object_walker dumps using diff
# Arguments:    file: the opened automation file object
#               timestamp1 & 2: the ojject_walker output timestamps to compare
# Returns:      nothing
#-------------------------------------------------------------------------------------------------------------

def diff_dumps(file, timestamp1, timestamp2)
  begin
    puts "Getting diff comparison from dumps at #{timestamp1} and #{timestamp2}"
    tempfile1 = Tempfile.new('owr-')
    tempfile2 = Tempfile.new('owr-')
    find_dump(file, timestamp1, tempfile1)
    find_dump(file, timestamp2, tempfile2)
    tempfile1.close
    tempfile2.close
    difference = `diff #{tempfile1.path} #{tempfile2.path}`
    puts difference
  ensure
    tempfile1.unlink
    tempfile2.unlink
  end
end

begin
  options = {:list => false, :filename => nil, :timestamp => nil, :diff => nil}
  
  parser = OptionParser.new do|opts|
    opts.banner = "Usage: object_walker_reader.rb [options]"
    opts.on('-l', '--list', 'list object_walker dumps in the file') do
      options[:list] = true;
    end
    opts.on('-f', '--file filename', 'Full file path to automation.log (if not /var/www/miq/vmdb/log/automtion.log)') do |filename|
      options[:filename] = filename;
    end
    opts.on('-t', '--timestamp timestamp', 'Date/time of the object_walker dump to be listed (hint: copy from -l output)') do |timestamp|
      options[:timestamp] = timestamp;
    end
    opts.on('-d', '--diff timestamp1,timestamp2', Array, 'Date/time of two object_walker dumps to be compared using \'diff\'') do |diff_timestamps|
      unless diff_timestamps.length == 2
        puts "timestamps must be timestamp1,timestamp2 list"
        exit!
      end
      options[:diff] = diff_timestamps
    end
    opts.on('-h', '--help', 'Displays Help') do
      puts opts
      exit
    end
  end
  parser.parse!
  
  if options[:timestamp]
    if options[:list]
      puts "The options -t and -l should not be used together: use -l to list the dumps in the log file, and -t to select a particular dump timestamp"
      exit!
    end
    unless valid_timestamp_re.match(options[:timestamp])
      puts "Invalid timestamp format"
      exit!
    end
  end
    
  if options[:filename].nil?
    filename = "/var/www/miq/vmdb/log/automation.log"
  else
    filename = options[:filename]
  end
  
  begin
    file = File.new(filename, "r:UTF-8")
  rescue => err
    puts "Error opening log file: #{err}"
    exit!
  end
  
  if options[:list]
    list_dumps(file)
  elsif options[:diff]
    diff_dumps(file, options[:diff][0], options[:diff][1])
  else
    find_dump(file, options[:timestamp])
  end
  
rescue => err
  puts "#{err}"
  exit!
ensure
  file.close unless file.nil?
end
