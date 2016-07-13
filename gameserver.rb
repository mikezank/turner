#!/usr/bin/ruby
#
#  GameServer -- Responds to join requests and connects the requesting game client to a running GameSession.
#
#  - The join request can also specify a particular GameSession to join by using a code
#  - GameServer also manages port assignments to each GameSession and reuses them
#
require 'byebug'
require 'rubygems'
require 'ffi-rzmq'
require 'logger'
require_relative 'constants.rb'

class GameChoice
  
  attr_reader :numplayers, :numports
  
  def initialize(numplayers, numports)
    @numplayers, @numports = numplayers, numports
  end
  
end

class PlayerSlot
  
  attr_reader :game_name, :session_code, :port
  
  def initialize(game_name, session_code, port)
    @game_name, @session_code, @port = game_name, session_code, port
  end
  
end

class NoPortsError < StandardError; end

class PortManager
  #
  # manages port assignments for all running GameSessions
  #
  @@LOW_PORT = 5600
  @@HIGH_PORT = 9999
  @@MAX_PORTS = @@HIGH_PORT - @@LOW_PORT + 1
  
  def initialize
    @used_ports = []
  end
  
  def request_ports(count)
    ports = []
    count.times {ports << get_port}
    $LOG.debug "After port request, used_ports = #{@used_ports}"
    ports
  end
  
  def reclaim_ports(ports)
    ports.each {|port| @used_ports.delete(port)}
    $LOG.debug "After port reclaim, used_ports = #{@used_ports}"
  end
  
  private
  
  def get_port
    if @used_ports.length == @@MAX_PORTS
      $LOG.error "All ports are in use"
      raise NoPortsError
    end
    
    port = 0 # to establish scope
    loop do
      port = @@LOW_PORT + rand(@@MAX_PORTS)
      break unless @used_ports.include? port
    end
    @used_ports << port
    port
  end
  
end

class GameServer
  
  def initialize
    @game_choices = {}
    @game_choices["turner"] = GameChoice.new(3, 6)
    @game_choices["pairs"] = GameChoice.new(2, 5)
    @player_slots = []
    @port_manager = PortManager.new
  end
  
  def get_ports(numports)
    ports = []
    numports.times { ports << rand(100)}
    ports
  end
  
  def find_slot(game_name, session_code)
    @player_slots.each do |slot|
      if slot.game_name == game_name && slot.session_code == session_code
        @player_slots.delete(slot) # slot is no longer available
        return slot.port
      end
    end
    nil
  end
  
  def create_session(game_name, session_code)
    ports = @port_manager.request_ports(@game_choices[game_name].numports)
    launch_session(game_name, ports)
    @game_choices[game_name].numplayers.times do |n|
      @player_slots << PlayerSlot.new(game_name, session_code, ports.pop)
    end
  end
  
  def game_exists?(game_name)
    @game_choices.has_key?(game_name)
  end
  
  private
  
  def launch_session(game_name, ports)
    launch_command = "ruby #{game_name}game.rb"
    ports.each {|port| launch_command += " " + port.to_s}
    pid = Process.spawn(launch_command)
    $LOG.debug "Launched #{game_name} session with ports #{ports}, pid = #{pid}"
    Thread.new {
      Process.wait(pid)
      $LOG.debug "Process finished, pid = #{pid}"
      @port_manager.reclaim_ports(ports)
    }
  end

end

#
# main
#
def error_check(rc)
  if ZMQ::Util.resultcode_ok?(rc)
    false
  else
    STDERR.puts "Operation failed, errno [#{ZMQ::Util.errno}] description [#{ZMQ::Util.error_string}]"
    caller(1).each { |callstack| STDERR.puts(callstack) }
    true
  end
end

def send_reply(reply)
  error_check(socket.send_string(reply))
  $LOG.debug "Sent reply: #{reply}"
end

$LOG = Logger.new(STDOUT)
# $LOG = Logger.new('gameserver.log') # use this for production version
$LOG.progname = "GameServer"



# start gbroker for this server and connect to it
pid = Process.spawn("ruby gbroker.rb #{GConst::BROKER_PLAYER_PORT} #{GConst::BROKER_SERVER_PORT}")
context = ZMQ::Context.new
at_exit { 
  Process.kill(-9, pid)
  context.terminate
  } # do something here
socket = context.socket(ZMQ::REP)
error_check(socket.connect("tcp://localhost:#{GConst::BROKER_SERVER_PORT}"))

gs = GameServer.new
#
# this is the game request loop
#
# player (client) must request using the following format:
#
#    join-gamename-sessioncode
#
#  where gamename is the name of the game to join
#  and sessioncode is the code for a private GameSession (can be left blank)
#
# successful server response is the port number to communicate with the GameSession
#
# unsuccessful server response is "error"
#
loop do
  error_check(socket.recv_string(message = ''))
  $LOG.debug "Request received; message = #{message}"
  parts = message.split('-')
  
  unless (parts[0] == "join") && (gs.game_exists? parts[1])
    send_reply("error")
    next
  end
  
  port = gs.find_slot(game_name, session_code)
  unless port
    begin
      gs.create_session(game_name, session_code)
      port = gs.find_slot(game_name, session_code)
    rescue NoPortsError
      send_reply("error")
      next
    end
  end
  
  send_reply(port.to_s)
end
