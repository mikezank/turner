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

	def initialize(pids, logger)
    @pids = pids
    @players = 0
    @baseport = @@BASE_PORT
    @logger = logger
    @logger.log('Initializing')
  end
    
	def game_request
    # start a broker for the player
    @players += 1
    @pids << Process.spawn("ruby gbroker.rb #{@baseport + 5 + @players} #{@baseport + @players}")
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
    @pids << Process.spawn("ruby gsession.rb #{@baseport + 5}")
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
pids = [] # keep track of all spawned processes

# Trap ^C 
Signal.trap("INT") {
  pids.each do |pid|
    begin
      puts "Killing pid #{pid}"
      Process.kill(-9, pid)
      puts "Done"
    rescue
      puts "couldn't kill it"
    end
  end
  exit
}

logger = ZUtils::Logger.new('GameServer', true)
gs = GameServer.new(pids, logger)

# start gbroker for this server and connect to it
pids << Process.spawn("ruby gbroker.rb #{GConst::BROKER_PLAYER_PORT} #{GConst::BROKER_SERVER_PORT}")
context = ZMQ::Context.new
socket = context.socket(ZMQ::REP)
error_check(socket.connect("tcp://localhost:#{GConst::BROKER_SERVER_PORT}"))

loop do
  error_check(socket.recv_string(message = ''))
  logger.log("Request received; message = #{message}")
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


