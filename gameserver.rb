require 'byebug'

class GameFrame
  
  def initialize(code)
    @players = 1
    @code = code
  end
  
  def get_name
    @name
  end
  
  def get_code
    @code
  end
  
  def add_player
    @players += 1
    @players == @players_needed
  end
  
end

class TurnerGame < GameFrame
  
  def initialize(code)
    super(code)
    @players_needed = 3
    @name = "turner"
  end
  
end

class PairsGame < GameFrame
  
  def initialize(code)
    super(code)
    @players_needed = 2
    @name = "pairs"
  end
  
  def launch_game
    pid = Process.spawn("ruby pairsgame.rb")
  end
  
end

class GameServer
  
  @@VALID_CHARS = "ABCDEFGHJKMNPQRSTUVWXYZ"
  @@MAX_CODES = @@VALID_CHARS.length ** 2
  
  def initialize
    srand
    @runners = []
    @waiters = []
    @codes = []
  end
  
  def add_player(name)
    #
    # adds a player to a GameSession with the given name and returns the Session code
    #
    session = find_name(name)
    if session
      # there is a session with this game; add the player to it
      if session.add_player
        # GameSession is ready to start
        start_session(session)
      end
      return session.get_code
    end
    
    # there is no session with this game; create a new one
    code = make_code
    if name == "turner"
      @waiters << TurnerGame.new(code)
    elsif name == "pairs"
      @waiters << PairsGame.new(code)
    else
      puts "No such game: #{name}"
      raise SystemExit
    end
    code
  end
  
  def add_player_with_code(name, code)
    #
    # adds a player to a GameSession with the specified code
    #
    session = find_code(code)
    return false unless session # fail if no such code
    return false unless session.get_name == name # fail if that session is running a different game
    if session.add_player
      # GameSession is ready to start
      start_session(session)
    end
    true
  end
  
  private
  
  def start_session(session)
    puts "GameSession #{session} is starting"
    @waiters.delete(session)
    @runners << session
    pid = session.launch_game
    p self
    wait_for_finish(pid, session)
  end
  
  def wait_for_finish(pid, session)
    thread = Thread.new {Process.wait(pid)}
    thread.join
    puts "pid #{pid} finished"
    end_session(session)
    p self
  end
  
  def end_session(session)
    @codes.delete(session.get_code)
    @runners.delete(session)
  end
  
  def find_name(name)
    @waiters.each {|session| return session if session.get_name == name}
    nil
  end
  
  def find_code(code)
    @waiters.each {|session| return session if session.get_code == code}
    nil
  end
  
  def find_running_session(code)
    @runners.each {|session| return session if session.get_code == code}
    nil
  end
  
  def make_code
    if @codes.length == @@MAX_CODES
      puts "Can't assign any more codes"
      raise SystemExit
    end
    loop do
      char1 = @@VALID_CHARS[rand(@@VALID_CHARS.length)]
      char2 = @@VALID_CHARS[rand(@@VALID_CHARS.length)]
      code = char1 + char2
      next if @codes.include? code
      @codes << code
      return code
    end
  end
    
end

#
# main
#
gs = GameServer.new
gs.add_player('pairs')
gs.add_player('pairs')
sleep 20

