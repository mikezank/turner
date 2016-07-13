#
# ruby gbroker.rb req_port rep_port
#
# where req_port is the port that will issue REQs (connected to ROUTER)
#   and rep_port is the port that will issue REPs (connected to DEALER)
#
require 'rubygems'
require 'ffi-rzmq'
require 'logger'

$LOG = Logger.new(STDOUT)
# $LOG = Logger.new('gameserver.log') # use this for production version
$LOG.progname = "GBroker"

unless ARGV.length == 2
  $LOG.error "Must run GBroker with two parameters: req_port rep_port"
  exit
end

context = ZMQ::Context.new
frontend = context.socket(ZMQ::ROUTER)
backend = context.socket(ZMQ::DEALER)

frontend.bind('tcp://*:' + ARGV[0])
backend.bind('tcp://*:' + ARGV[1])

$LOG.debug "GBroker running connecting REQ:#{ARGV[0]} to REP:#{ARGV[1]}"

poller = ZMQ::Device.new(frontend, backend)

