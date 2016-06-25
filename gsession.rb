#!/usr/bin/env ruby

# GameSession gives commands to each Player until the Game is won

require 'rubygems'
require 'ffi-rzmq'
require 'byebug'

require_relative 'constants.rb'
require_relative 'board.rb'
require_relative 'zlogger.rb'

class Player
  
  def error_check(rc)
      if ZMQ::Util.resultcode_ok?(rc)
        false
      else
        STDERR.puts "Operation failed, errno [#{ZMQ::Util.errno}] description [#{ZMQ::Util.error_string}]"
        caller(1).each { |callstack| STDERR.puts(callstack) }
        true
      end
  end
  
  def set_name(name)
    @name = name
  end
  
  def initialize(context, port, logger)
    @logger = logger
    @port = port
    @socket = context.socket(ZMQ::REQ)
    error_check(@socket.connect("tcp://localhost:#{port}"))
  end
  
  def note_other_players(other1, other2)
    @other1, @other2 = other1, other2
  end
  
  def send_command(command)
    error_check(@socket.send_string(command))
    @logger.log("Sent '#{command}' to player #{@name} over port #{@port}")
    error_check(@socket.recv_string(reply=''))
    @logger.log("Received '#{reply}' from player #{@name}")
    reply
  end
  
  def update_others(command)
    @other1.send_command(command)
    @other2.send_command(command)
  end
  
  def make_move(board)
    letter = send_command('pick')
    if board.already_chosen? letter
      # letter was already chosen once before
      send_command('chosen')
      update_others('picked2|' + letter)
      return false
    end
    
    if letter == '*'
      # player took too long to pick a letter and lost their turn
      send_command('timeout')
      update_others('timedout')
      return false
    end
    
    found_locs = board.fill_letter(letter)
    found_count = found_locs.length
    if found_count == 0
      # no such letter in the puzzle
      send_command('none')
      return false
    end
    
    # there are one or more of the letter in the puzzle
    payload = ''
    found_locs.each do |loc|
      payload += loc.to_s + '-' # will be used to split the locations by GPlayer
    end
    payload = payload[0..payload.length-2] # remove extra "-"
    send_command('update|' + payload)
    update_others('update|' + payload)
    send_command('found|' + found_count.to_s)
      
    guess = send_command('guess')
    if guess == board.phrase
      send_command('won')
      update_others('lost')
      return true
    else
      return false
    end
  end
end

def abort_on_bad_reply(reply)
  if reply != 'ready'
    puts "Illegal reply from ready command"
    raise SystemExit
  end
end

def get_random_order(*players)
  # returns a random playing order
  srand
  order = GConst::PLAYER_ORDERS[rand(6)]
  [players[order[0]], players[order[1]], players[order[2]]]
end

def puzzle_to_spaces(puzzle)
  spaces = String.new(puzzle)
  spaces.length.times do |n|
    spaces[n] = "_" if spaces[n] != " "
  end
  spaces
end

#
# main
#
baseport = ARGV[0]
logger = ZUtils::Logger.new('GameSession', true)
logger.log("Game started on base port #{baseport}")
context = ZMQ::Context.new(1)

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

player1 = Player.new(context, baseport.to_i + 1, logger)
player2 = Player.new(context, baseport.to_i + 2, logger)
player3 = Player.new(context, baseport.to_i + 3, logger)

reply = player1.send_command('ready')
player1.set_name(reply)
reply = player2.send_command('ready')
player2.set_name(reply)
reply = player3.send_command('ready')
player3.set_name(reply)

logger.log("All three players ready")
order = get_random_order(player1, player2, player3)
order[0].note_other_players(order[1], order[2])
order[1].note_other_players(order[2], order[0])
order[2].note_other_players(order[0], order[1])
game_won = false
game_answer = "london bridge is falling down".upcase
board = Board.new(game_answer)
spaces = puzzle_to_spaces(game_answer)
reply = player1.send_command("board|#{spaces}")
reply = player2.send_command("board|#{spaces}")
reply = player3.send_command("board|#{spaces}")

until game_won do
  0.upto(2).each do |player|
    game_won = order[player].make_move(board)
    break if game_won
  end
end

context.terminate

