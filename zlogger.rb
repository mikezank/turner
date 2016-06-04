require 'date'

module ZUtils
  
  class Logger
    
    def initialize(tag, testmode)
      filename = DateTime.now.strftime("%Y%m%d%H%M%S") + '-' + tag + '.log'
      @tag = tag
      @logfile = File.open(filename, 'w')
      @testmode = testmode
    end
    
    def log(message)
      timestamp = DateTime.now.strftime("%Y-%m-%d %H:%M:%S")
      logline = timestamp + " " + @tag + " " + message + "\n"
      @logfile.write(logline)
      puts logline if @testmode
    end
    
    def close
      @logfile.close
    end
  end
  
end
      