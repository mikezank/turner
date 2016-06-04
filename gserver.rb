#!/usr/bin/env ruby
#
# GameServer responds to Player requests and transfers each Player to a running GameSession

require 'rubygems'
require 'ffi-rzmq'
#require 'byebug'

require_relative 'constants.rb'
require_relative 'zlogger.rb'

class GameServer

	@@MAX_SESSIONS = 5
	@@BASE_PORT = GConst::GAME_SERVER_BASE_PORT
	@@PORT_GAP = 10

	def initialize(logger)
    @logger = logger
    @logger.log('Initializing')
    
    @idle = [] # idle GameSessions
    @busy = [] # busy GameSessions
    @waiter = nil # current GameSession waiting to be filled with Players
    
    baseport = @@BASE_PORT
    @@MAX_SESSIONS.times do
      @idle << GameSession.new(baseport, @logger)
      baseport += @@PORT_GAP
    end
    @logger.log("Started #{@@MAX_SESSIONS} GameSessions")
    @waiter = @idle.pop
	end
	
	def game_request
    # return the port number for the Player to listen for Game commands; if GameServer is full, return nil
    unless @waiter
      # there is no available waiter so the GameServer is full
      return nil
    end
		if @waiter.game_is_full?
			@logger.log("Session is full but it shouldn't be")
			return nil
		end
		port = @waiter.add_player
		if @waiter.game_is_full?
      # GameSession has required number of Players; select another waiter
      @busy << @waiter
      if @idle.length == 0
        # there are no idle GameSessions available -- GameServer is full
        @waiter = nil
      else
        @waiter = @idle.pop
			end
		end
    port
	end
	
end

class GameSession

	@@PLAYERS_NEEDED = 3

	def initialize(baseport, logger)
    @logger = logger
    @logger.log("GameSession starting on base port #{baseport}")
		@port = baseport
		@player_count = 0
    Process.spawn("ruby gsession.rb #{@port}")
	end
	
	def add_player
		unless game_is_full?
      @port += 1
			@logger.log("Player added to session on port #{@port}")
			@player_count += 1
			@port
    end
	end
	
	def game_is_full?
		@player_count == @@PLAYERS_NEEDED
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
socket.connect("tcp://localhost:#{GConst::BROKER_SERVER_PORT}")

loop do
  socket.recv_string(message = '')
  unless message == 'join'
    logger.log("Illegal player message received: #{message}")
    socket.send_string('no')
    next
  end
  port = gs.game_request
  unless port
    puts "Server is full"
    next
  end
  logger.log("Sending #{port} to Player")
  socket.send_string("#{port}")
end
