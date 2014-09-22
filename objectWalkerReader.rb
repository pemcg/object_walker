#!/usr/bin/env ruby
#
# objectWalkerReader - extract the latest (no arguments), or a selected objectWalker dump from automation.log or other renamed or
# saved log file.
#
# Usage: objectWalkerReader.rb [options]
#     -l, --list                       list objectWalker dumps in the file
#     -f, --file filename              Full file path to automation.log
#     -t, --timestamp timestamp        Date/time of the objectWalker dump to be listed (hint: copy from -l output)
#     -h, --help                       Displays Help
#
# Examples:
#
# ./objectWalkerReader.rb -l
# Found objectWalker dump at 2014-09-17T13:28:42.052043
# Found objectWalker dump at 2014-09-17T13:34:52.649359
# Found objectWalker dump at 2014-09-17T15:06:29.250086
# Found objectWalker dump at 2014-09-17T15:22:46.034628
# Found objectWalker dump at 2014-09-18T07:56:08.201025
# ...
# 
# ./objectWalkerReader.rb -l -f /Documents/CloudForms/cf30-automation-log
# Found objectWalker dump at 2014-09-18T09:52:28.797868
# Found objectWalker dump at 2014-09-18T09:53:31.455892
# Found objectWalker dump at 2014-09-18T10:05:39.040744
# Found objectWalker dump at 2014-09-18T12:00:59.142460
# ...
# 
# ./objectWalkerReader.rb -t 2014-09-18T09:44:27.146812
# objectWalker 1.0 - EVM Automate Method Started
#      objectWalker:   Dumping $evm.root
#      objectWalker:   $evm.root.ae_provider_category = infrastructure   (type: String)
#      objectWalker:   $evm.root.class = Methods   (type: String)
#      objectWalker:   $evm.root.instance = objectWalker   (type: String)
#      objectWalker:   $evm.root['miq_server'] => # <MiqAeMethodService::MiqAeServiceMiqServer:0x00000008f242b8>   (type: DRb::DRbObject)
#      |    objectWalker:   $evm.root['miq_server'].build = 20140822170824_3268809   (type: String)
#      |    objectWalker:   $evm.root['miq_server'].capabilities = {:vixDisk=>true, :concurrent_miqproxies=>2}   (type: Hash)
#      |    objectWalker:   $evm.root['miq_server'].cpu_time = 2312.0   (type: Float)
#      |    objectWalker:   $evm.root['miq_server'].drb_uri = druby://127.0.0.1:50656   (type: String)
#      |    objectWalker:   $evm.root['miq_server'].guid = 5132a574-3d76-11e4-9150-001a4aa80204   (type: String)
#      |    objectWalker:   $evm.root['miq_server'].has_active_userinterface = true   (type: TrueClass)
#      |    objectWalker:   $evm.root['miq_server'].has_active_webservices = true   (type: TrueClass)
#      |    objectWalker:   $evm.root['miq_server'].hostname = cf31b2-1.bit63.net   (type: String)
#      |    objectWalker:   $evm.root['miq_server'].id = 1000000000001   (type: Fixnum)
#      |    objectWalker:   $evm.root['miq_server'].ipaddress = 192.168.2.77   (type: String)
# ... 
#
# Author:	Peter McGowan (pemcg@redhat.com)
#           Copyright 2014 Peter McGowan, Red Hat
#
# Revision History
#
# Original      1.0     18-Sep-2014
#  

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
