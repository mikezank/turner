#!/usr/bin/env ruby

#
# ruby gbroker.rb req_port rep_port
#
# where req_port is the port that will issue REQs (connected to ROUTER)
#   and rep_port is the port that will issue REPs (connected to DEALER)

require 'rubygems'
require 'ffi-rzmq'

unless ARGV.length == 2
  puts "Must run gbroker with two parameters: req_port rep_port"
  raise SystemExit
end
context = ZMQ::Context.new
frontend = context.socket(ZMQ::ROUTER)
backend = context.socket(ZMQ::DEALER)

frontend.bind('tcp://*:' + ARGV[0])
backend.bind('tcp://*:' + ARGV[1])

poller = ZMQ::Device.new(frontend, backend)

