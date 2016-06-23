class Board

	@@LINE_LENGTH = 20
	@@LINE_COUNT = 5
  @@LETTER_COUNT = @@LINE_COUNT * @@LINE_LENGTH
	
	attr_reader :phrase

	def initialize(phrase)
    @phrase = phrase.upcase
    words = @phrase.split(" ")
    @chosen_letters = []
		@lines = []
    @letters = []
    @visible = []
    init_lines
		@row = 0
		@ptr = 0
		words.each do |word|
			unless place_word(word)
				puts "Could not place #{word}"
				raise "Phrase too big for Board"
			end
		end
    init_letters
	end
  
  def already_chosen?(letter)
    @chosen_letters.include? letter
  end
  
	def pprint
		@lines.each do |line|
			line.each {|ch| print ch + " "}
			puts
		end
	end
  
  def bprint
    @@LINE_COUNT.times do |lineno|
      @@LINE_LENGTH.times do |charno|
        letterno = lineno * @@LINE_LENGTH + charno
        if @visible[letterno]
          print @letters[letterno] + " "
        else
          print "_ "
        end
      end
      puts
    end
  end
  
  def get_letters
    letter_string = ''
    @@LINE_COUNT.times do |lineno|
      @@LINE_LENGTH.times do |charno|
        letterno = lineno * @@LINE_LENGTH + charno
        if @visible[letterno]
          letter_string << @letters[letterno]
        else
          letter_string << "_"
        end
      end
      # letter_string << "\n"
    end
    letter_string
  end
  
  def fill_letter(letter)
    found_count = 0
    @@LETTER_COUNT.times do |letterno|
      if @letters[letterno] == letter
        @visible[letterno] = true
        found_count += 1
      end
    end
    @chosen_letters << letter
    found_count
  end
	
	private

	def init_lines
		blankline = []
		@@LINE_LENGTH.times {|n| blankline << " "}
		@@LINE_COUNT.times {|n| @lines << Array.new(blankline)}
	end

	def place_word(word)

		return false if @row >= @@LINE_COUNT  # Board is full 

		if @ptr + word.length <= @@LINE_LENGTH
			
			# word can fit on the current line
			@lines[@row][@ptr..@ptr+word.length-1] = word.chars
			@ptr += word.length + 1
			if @ptr >= @@LINE_LENGTH  # is this line full?
				@ptr = 0
				@row += 1
			end
			return true
		else
			
			# word can't fit on the current line
			@row += 1
			if @row >= @@LINE_COUNT  # is Board full?
				return false
			end
			@lines[@row][0..word.length-1] = word.chars
			@ptr = word.length + 1
			if @ptr >= @@LINE_LENGTH  # is this line full?
				@ptr = 0
				@row += 1
			end
			return true
		end
	end
  
  def init_letters
    @@LINE_COUNT.times do |lineno|
      @@LINE_LENGTH.times do |charno|
        letter = @lines[lineno][charno]
        letterno = lineno * @@LINE_LENGTH + charno
        @letters[letterno] = letter
        @visible[letterno] = ["'", ":", " "].include? letter
      end
    end
  end

end

