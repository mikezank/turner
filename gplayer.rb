#!/usr/bin/env ruby

# Player

require 'rubygems'
require 'ffi-rzmq'
require 'byebug'

require_relative 'constants.rb'
require_relative 'zlogger.rb'

class GameComm
  
  def initialize(context, port, logger)
    @socket = context.socket(ZMQ::REP)
    error_check(@socket.connect("tcp://#{GConst::SERVER_IP}:#{port}"))
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

#
# main
#
name = ARGV.length == 1 ? ARGV[0] : 'unknown' 
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

socket = context.socket(ZMQ::REQ)
socket.connect("tcp://#{GConst::SERVER_IP}:#{GConst::BROKER_PLAYER_PORT}")

socket.send_string("join")
socket.recv_string(message = '')
logger.log("Received reply from GameSession: '#{message}'")
port = message.to_i
gc = GameComm.new(context, port, logger)

game_over = false
until game_over
  command, payload = gc.get_command
  case command
  when 'ready'
    gc.send_reply(name)
    gc.set_name(name)
    puts "Ready to play"
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
    letter = $stdin.gets.chomp
    gc.send_reply(letter)
  when 'chosen'
    puts "That letter was already chosen"
    gc.send_reply('ok')
  when 'timeout'
    puts "Took too long for your turn"
    gc.send_reply('ok')
  when 'found'
    found_count = payload.to_i
    case found_count
    when 1 then 
      puts "Yes, we have one letter #{letter}"
    when 0 then 
      puts "No, there is no letter #{letter}"
    else 
      puts "Yes, we have #{found_count} #{letter}'s"
    end
    gc.send_reply('ok')
  when 'guess'
    puts "Guess:"
    guess = $stdin.gets.chomp
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

