#!/usr/bin/env ruby
#
# object_walker_reader - extract the latest (no arguments), or a selected object_walker dump from automation.log or other renamed or
# saved log file.
#
# Usage: object_walker_reader.rb [options]
#     -l, --list                       list object_walker dumps in the file
#     -f, --file filename              Full file path to automation.log
#     -t, --timestamp timestamp        Date/time of the object_walker dump to be listed (hint: copy from -l output)
#     -h, --help                       Displays Help
#
# Examples:
#
# ./object_walker_reader.rb -l
# Found object_walker dump at 2014-09-17T13:28:42.052043
# Found object_walker dump at 2014-09-17T13:34:52.649359
# Found object_walker dump at 2014-09-17T15:06:29.250086
# Found object_walker dump at 2014-09-17T15:22:46.034628
# Found object_walker dump at 2014-09-18T07:56:08.201025
# ...
# 
# ./object_walker_reader.rb -l -f /Documents/CloudForms/cf30-automation-log
# Found object_walker dump at 2014-09-18T09:52:28.797868
# Found object_walker dump at 2014-09-18T09:53:31.455892
# Found object_walker dump at 2014-09-18T10:05:39.040744
# Found object_walker dump at 2014-09-18T12:00:59.142460
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
#      |    object_walker:   $evm.root['miq_server'].has_active_userinterface = true   (type: TrueClass)
#      |    object_walker:   $evm.root['miq_server'].has_active_webservices = true   (type: TrueClass)
#      |    object_walker:   $evm.root['miq_server'].hostname = cf31b2-1.bit63.net   (type: String)
#      |    object_walker:   $evm.root['miq_server'].id = 1000000000001   (type: Fixnum)
#      |    object_walker:   $evm.root['miq_server'].ipaddress = 192.168.2.77   (type: String)
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
#  

require 'optparse'

valid_timestamp_re = /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}/
object_walker_start_re = /----\] I, \[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}) .*[Oo]bject_*[Ww]alker .* - EVM Automate Method Started/
object_walker_body_re = /.*(AEMethod [Oo]bject_*[Ww]alker|Defined Method)\> (.*)/
object_walker_end_re = /[Oo]bject_*[Ww]alker - EVM Automate Method Ended/
found_timestamp = false
dump_start = 0

options = {:list => false, :filename => nil, :timestamp => nil}

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
  opts.on('-h', '--help', 'Displays Help') do
    puts opts
    exit
  end
end
parser.parse!

if options[:timestamp]
  if options[:list]
    puts "The options -t and -l shoud not be used together: use -l to list the dumps in the log file, and -t to select a particular dump timestamp"
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
  file = File.new(filename, "r")
rescue => err
  puts "Error opening log file: #{err}"
  exit!
end
  
file.each do |line|
  match = object_walker_start_re.match(line)
  if match
    if options[:list]
      puts "Found object_walker dump at #{match[1]}"
    end
    if options[:timestamp]
      if options[:timestamp] == match[1]
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
if options[:timestamp] && !found_timestamp
  puts "Timestamp: #{options[:timestamp]} not found in log file"
  exit!
end

unless options[:list]
  file.seek(dump_start)
  file.each do |line|
    match = object_walker_body_re.match(line)
    if match
      puts match[2]
    end
    if object_walker_end_re.match(line)
      break
    end
  end
end
file.close
