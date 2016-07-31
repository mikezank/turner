#
# GameSession for Pairs game
#
require 'rubygems'
require 'ffi-rzmq'
require 'byebug'
require 'logger'

require_relative 'constants.rb'
#require_relative 'board.rb'

class Player
  
  def initialize(context, port)
    @port = port
    @socket = context.socket(ZMQ::REP)
    error_check(@socket.connect("tcp://localhost:#{port}"))
    $LOG.debug "Connected to port #{port}"
  end
  
  def set_name(name)
    @name = name
  end
  
  def note_other_players(other1, other2)
    @other1, @other2 = other1, other2
  end
  
  def get_command(command)
    error_check(@socket.recv_string(command=''))
    $LOG.debug "Received '#{command}' from player #{@name} over port #{@port}"
    commmand
  end
  
  def send_reply(reply)
    error_check(@socket.send_string(reply))
    $LOG.debug "Sent '#{reply}' from player #{@name}"
  end
  
  def close_socket
    puts "Closing socket"
    @socket.close if @socket
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
    
    update_others('picked|' + letter)
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
  
  private

  def update_others(command)
    @other1.send_command(command)
    @other2.send_command(command)
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
  
end

#
# main
#
# pairsgame is spawned with 5 ports as arguments
#
#   first two ports are REP ports for the GameSession
#   next two ports are REQ ports for each of the Players
#   final port is PUB port for GameSession (SUB port for all Players)
#
def abort_on_bad_reply(reply)
  if reply != 'ready'
    $LOG.error "Illegal reply from ready command"
    exit
  end
end

def puzzle_to_spaces(puzzle) # needed?
  spaces = String.new(puzzle)
  spaces.length.times do |n|
    spaces[n] = "_" if spaces[n] != " "
  end
  spaces
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



$LOG = Logger.new(STDOUT)
# $LOG = Logger.new('gameserver.log') # use this for production version
$LOG.progname = "PairsGame"

unless ARGV.length == 5
  $LOG.error "Not spawned with 5 ports"
  exit
end

# establish GBrokers for each player and connect to them
context = ZMQ::Context.new(1)
#at_exit { context.terminate } # do something here
players = []
2.times {|n| Process.spawn("ruby gbroker.rb #{ARGV[n]} #{ARGV[n+2]}")}

#
# need to set up one Thread for each Player to wait for commands
#

# for now just talk to the one player
player = Player.new(context, ARGV[0].to_i)
loop do
  player.get_command(command='')
  player.send_reply('OK')
end


=begin
3.times {|n| players << Player.new(context, ARGV[n].to_i)}

# wait for all players to be ready
3.times do |n|
  reply = players[n].send_command('ready')
  players[n].set_name(reply)
end

$LOG.debug "All three players ready"
players.shuffle! # randomly select the order of play
players[0].note_other_players(players[1], players[2])
players[1].note_other_players(players[2], players[0])
players[2].note_other_players(players[0], players[1])

game_won = false
game_answer = "london bridge is falling down".upcase
board = Board.new(game_answer)
payload = board.get_letters
#spaces = puzzle_to_spaces()
3.times {|n| reply = players[n].send_command("board|#{payload}")}

until game_won do
  0.upto(2).each do |player|
    game_won = players[player].make_move(board)
    break if game_won
  end
end
exit
puts "Trying to terminate"
byebug
3.times {|n| players[n].close_socket}
context.terminate if context
=end

