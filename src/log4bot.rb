class Log4Bot
    def initialize(logs_path)
        @colors = {
            :green => "\e[32m",
            :red => "\e[31m",
            :yellow => "\e[33m",
            :blue => "\e[34m",
            :magenta => "\e[35m",
            :cyan => "\e[36m",
            :white => "\e[37m",
            :reset => "\e[0m"
        }
        @hylights = {
            :bold => "\e[1m",
            :underline => "\e[4m",
            :blink => "\e[5m",
            :reverse => "\e[7m"
        }
        @log_level = {
            :debug => 0,
            :info => 1,
            :warn => 2,
            :error => 3,
            :fatal => 4,
            :security => 5,
            :icewall => 6
        }
        @timeformat = "%Y-%m-%d %H:%M:%S"
        @log_name_format = "%Y-%m-%d"
        @timezone = "UTC" # International Time Zone
        @logs_path = logs_path
    end

    def log(message, level = :info)
        
        write("#{timestamp} [#{level.to_s.upcase}] #{message}")


        case level
        when :debug
            out = "#{timestamp} [#{@colors[:cyan]}DEBUG#{@colors[:reset]}] #{message}"
        when :info
            out = "#{timestamp} [#{@colors[:green]}INFO#{@colors[:reset]}] #{message}"
        when :warn
            out = "#{timestamp} [#{@colors[:yellow]}WARN#{@colors[:reset]}] #{message}"
        when :error
            out = "#{timestamp} [#{@colors[:red]}ERROR#{@colors[:reset]}] #{message}"
        when :fatal
            out = "#{timestamp} [#{@colors[:red]}#{@hylights[:blink]}FATAL#{@colors[:reset]}] #{message}"
        when :security
            out = "#{timestamp} [#{@colors[:red]}#{@hylights[:reverse]}SECURITY#{@colors[:reset]}] #{message}"
        when :icewall
            out = "#{timestamp} [#{@colors[:magenta]}ICEWALL#{@colors[:reset]}] #{message}"
        else
            out = "#{timestamp} [#{@colors[:green]}INFO#{@colors[:reset]}] #{message}"
        end

        puts out
    end


    private
    def timestamp(fmt = @timeformat)
        Time.now().strftime(fmt)
        
    end
    
    def write(log)
        File.open(@logs_path + "/" + timestamp(@log_name_format) + ".log", "a") do |file|
            file.puts log
        end
    end

    
end