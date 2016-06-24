#!/usr/bin/env ruby

# Player

require 'rubygems'
require 'ffi-rzmq'
require 'byebug'

require_relative 'constants.rb'
require_relative 'zlogger.rb'

class GameComm
  
  def initialize(context, server, port, logger)
    @port = port
    @socket = context.socket(ZMQ::REP)
    error_check(@socket.connect("tcp://#{server}:#{port}"))
    @logger = logger
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
  
  def get_command
    puts "waiting for a command on port #{@port}"
    error_check(@socket.recv_string(message=''))
    @logger.log("Player #{@name} received message '#{message}'")
    parts = message.split("|")
    command = parts[0]
    payload = parts.length > 1 ? parts[1] : nil
    [command, payload]
  end
  
  def send_reply(reply)
    error_check(@socket.send_string(reply))
    @logger.log("Player #{@name} sent reply '#{reply}'")
  end
  
  def set_name(name)
    @name = name
  end
  
end

class Puzzle
  
  def initialize(letters)
    @letters = letters
  end
  
  def turn_letters(letter, locations)
    locations.each do |loc|
      @letters[loc] = letter
    end
  end
  
  def get_letters
    @letters
  end
  
end

#
# main
#
name = ARGV.length < 1 ? 'unknown' : ARGV[0]
runlocal = ARGV.length == 2 && ARGV[1] == 'local'
logger = ZUtils::Logger.new('GPlayer', true)

context = ZMQ::Context.new
# Trap ^C 
#Signal.trap("INT") { 
#  puts "\nReleasing ports..."
#  context.terminate
#  exit
#}

# Trap `Kill `
#Signal.trap("TERM") {
#  puts "\nReleasing ports..."
#  context.terminate
#  exit
#}

#Signal.trap("EXIT") {
#  puts "\nReleasing ports..."
#  context.terminate
#  exit
#}

server = runlocal ? 'localhost' : GConst::SERVER_IP
socket = context.socket(ZMQ::REQ)
socket.connect("tcp://#{server}:#{GConst::BROKER_PLAYER_PORT}")

socket.send_string("join")
socket.recv_string(message = '')
logger.log("Received reply from GameSession: '#{message}'")
port = message.to_i
gc = GameComm.new(context, server, port, logger)
socket.send_string('connected')
socket.recv_string(message='')
if message != 'ok'
  puts "Illegal message received from GameServer: '#{message}'"
  raise SystemExit
end

game_over = false
until game_over
  command, payload = gc.get_command
  case command
  when 'ready'
    gc.send_reply(name)
    gc.set_name(name)
    puts "Ready to play"
  when 'board'
    gc.send_reply('ok')
    puzzle = Puzzle.new(payload)
    puts "Board load:"
    puts payload
  when 'update'
    gc.send_reply('ok')
    puts "Board update:"
    puts payload
  when 'done'
    gc.send_reply('done')
    puts "Game over.  You lost."
    game_over = true
  when 'won'
    gc.send_reply('ok')
    puts "Game over.  You won!"
    game_over = true
  when 'pick'
    print "Letter: "
    letter = $stdin.gets.chomp.upcase
    gc.send_reply(letter)
  when 'chosen'
    puts "That letter was already chosen"
    gc.send_reply('ok')
  when 'timeout'
    puts "Took too long for your turn"
    gc.send_reply('ok')
  when 'none'
    puts "No, there is no letter #{letter}"
    gc.send_reply('ok')
  when 'found'
    found_locs = payload.split("|")
    found_count = found_locs.length
    case found_count
    when 1 then 
      puts "Yes, we have one letter #{letter}"
    when 0 then 
      puts "Should not get here!"
    else 
      puts "Yes, we have #{found_count} #{letter}'s"
    end
    puzzle.turn_letters(letter, found_locs)
    gc.send_reply('ok')
    puts "Board update:"
    puts puzzle.get_letters
  when 'guess'
    puts "Guess:"
    guess = $stdin.gets.chomp.upcase
    gc.send_reply(guess)
  when 'picked2'
    puts "Letter #{payload} was picked again"
    gc.send_reply('ok')
  when 'picked'
    puts "Letter #{payload} was picked"
    gc.send_reply('ok')
  when 'timedout'
    puts "Player timed out"
    gc.send_reply('ok')
  when 'lost'
    puts "You lost."
    game_over = true
    gc.send_reply('ok')
  else
    puts "Illegal command received: #{command}"
    raise SystemExit
  end
end

context.terminate

