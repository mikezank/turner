#!/usr/bin/env ruby
#
# GameServer responds to Player requests and transfers each Player to a running GameSession

require 'rubygems'
require 'ffi-rzmq'
#require 'byebug'

require_relative 'constants.rb'
require_relative 'zlogger.rb'

class GameServer

	@@PLAYER_COUNT = 3
	@@BASE_PORT = GConst::GAME_SERVER_BASE_PORT
	@@PORT_GAP = 10

	def initialize(logger)
    @players = 0
    @baseport = @@BASE_PORT
    @logger = logger
    @logger.log('Initializing')
  end
    
	def game_request
    # start a broker for the player
    @players += 1
    Process.spawn("ruby gbroker.rb #{@baseport + 5 + @players} #{@baseport + @players}")
    if @players < @@PLAYER_COUNT
      # not enough players to start a GameSession yet
      [@baseport + @players, false]
    else
      # found enough players
      port = @baseport + @players
      @players = 0
      [port, true]
    end
  end
  
  def make_session
    # enough players are waiting and ready so spawn a GameSession
    Process.spawn("ruby gsession.rb #{@baseport + 5}")
    @baseport += @@PORT_GAP
  end
  
end

def error_check(rc)
  if ZMQ::Util.resultcode_ok?(rc)
    false
  else
    STDERR.puts "Operation failed, errno [#{ZMQ::Util.errno}] description [#{ZMQ::Util.error_string}]"
    caller(1).each { |callstack| STDERR.puts(callstack) }
    true
  end
end

#
# main
#
logger = ZUtils::Logger.new('GameServer', true)
gs = GameServer.new(logger)

# start gbroker for this server and connect to it
Process.spawn("ruby gbroker.rb #{GConst::BROKER_PLAYER_PORT} #{GConst::BROKER_SERVER_PORT}")
context = ZMQ::Context.new
socket = context.socket(ZMQ::REP)
error_check(socket.connect("tcp://localhost:#{GConst::BROKER_SERVER_PORT}"))

loop do
  error_check(socket.recv_string(message = ''))
  unless message == 'join'
    logger.log("Illegal player message received: #{message}")
    error_check(socket.send_string('no'))
    next
  end
  port, ready = gs.game_request
  logger.log("Sending #{port} to Player")
  error_check(socket.send_string("#{port}"))
  error_check(socket.recv_string(message = ''))
  unless message == 'connected'
    logger.log("Illegal player message received: #{message}")
    error_check(socket.send_string('no'))
    next
  end
  logger.log("Sending 'ok' to Player")
  error_check(socket.send_string('ok'))
  gs.make_session if ready
end
