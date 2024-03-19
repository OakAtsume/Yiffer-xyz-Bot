require_relative("log4bot")
require("net/http")
require("json")

class Backend
  def initialize(port, host = "0.0.0.0", redirs = "src/redirs.json", iceChecks = "src/ice/checks.json", iceTracking = "src/ice/tracking.json")
    @logs = Log4Bot.new("logs")
    @buffer = 8000 # 8KB's buffer
    @Events = {}
    @Events[:request] = []
    @Events[:error] = []
    @Events[:onBlockedRequest] = [] # Request from blocked IP
    @Events[:onIceBlock] = [] # Icewall has blocked a request
    @Socket = TCPServer.new(host, port)
    @logs.log("Server started at #{host}:#{port}", :info)
    @Redir = JSON.parse(File.read(redirs))
		@IceChecksPath = iceChecks
		@IceTrackingPath = iceTracking
    @IceChecks = JSON.parse(File.read(iceChecks))
    @IceTracking = JSON.parse(File.read(iceTracking))

    Thread.new do
      loop do
        Thread.start(@Socket.accept) do |socket|
          data = socket.recv(@buffer)
          begin
            parsed = parse(data)
            host = extractHost(data, socket)
            if isBlocked?(host)
              call(:onBlockedRequest, host, parsed, socket)
              next
            end
            check = iceCheck(parsed)
						if check["status"]
							blockIce(host, check["reason"])
              call(:onIceBlock, host, check["reason"])
							call(:onBlockedRequest, host, parsed, socket)
              next
            end
            call(:request, host, parsed, socket)
          rescue => e
            puts (e)
            puts e.backtrace.join("\n")
            call(:error, e)
            # if socket is still open, close it
            if !socket.closed?
              socket.close
            end
          end
        end
      end
    end
  end

  def on(event, &block)
    @Events[event] << block
  end

  def call(event, *args)
    @Events[event].each do |block|
      block.call(*args)
    end
  end

  def start
    loop do
      sleep 1
    end
  end

  private

  def parse(data)
    headers, body = data.split("\r\n\r\n", 2)
    headers = headers.split("\r\n")
    method, path, version = headers.shift.split(" ")
    headers = headers.map { |header| header.split(": ", 2) }.to_h

    #  Remove any ?'s from path
    path = path.split("?")[0]
    

    # Redirs
    path = redirs(path)
    return { method: method, path: path, version: version, headers: headers, body: body }
  end

  def extractHost(data, socket)
    # Check if socket's IP is localhost, if so then look for x-forwarded-for header
    if socket.peeraddr[3] == "0.0.0.0" || socket.peeraddr[3] == "127.0.0.1"
      if data.include?("x-forwarded-for")
        return data.split("x-forwarded-for: ")[1].split("\r\n")[0]
      end
    end
    return socket.peeraddr[3]
  end

  def redirs(path)
    # Remove any lingering /'s or .'s
    path = path.gsub(/\/+/, "/").gsub(/\.\./, "")
    if @Redir.key?(path)
      return @Redir[path]
    else
      return path
    end
  end

  def isBlocked?(host)
    refreshIce
    if @IceTracking["blocked"].map { |x| x["ip"] }.include?(host)
      return true
    else
      return false
    end
  end

  def iceCheck(rawParse)
    refreshIce
    flagged = false
    @IceChecks.each do |check|
      regex = Regexp.new(check["regex"])
      case check["point"]
      when "path"
        if rawParse[:path].match(regex)
          flagged = true
        end
      when "header"
        rawParse[:headers].each do |header|
          if header[0].match(regex) || header[1].match(regex)
            flagged = true
          end
        end
      when "body"
        if rawParse[:body].match(regex)
          flagged = true
        end
      when "all"
        if rawParse[:path].match(regex)
          flagged = true
        end
        rawParse[:headers].each do |header|
          if header[0].match(regex) || header[1].match(regex)
            flagged = true
          end
        end
        if rawParse[:body].match(regex)
          flagged = true
        end
      end
      if flagged
        return {
					"reason" => check["flag"],
					"status" => true,	
				}
      end
    end
    return {
			"reason" => "No match",
			"status" => false,
		}
  end

  def blockIce(host, reason, untilTime = nil, at = Time.now.to_i)
    refreshIce
    @IceTracking["blocked"] << { "ip" => host, "reason" => reason, "until" => untilTime, "at" => at }
    File.write(@IceTrackingPath, JSON.pretty_generate(@IceTracking))
  end

  def refreshIce
    @IceChecks = JSON.parse(File.read(@IceChecksPath))
    @IceTracking = JSON.parse(File.read(@IceTrackingPath))
  end
end


class Responder
  def initialize(dir, errordir)
    @dir = dir
    @errordir = errordir
    @Exts = %w[
      ico
      png
      jpg
      jpeg
      gif
      svg
      webp
    ]
  end

  def gen(header, contentype, content)
    reply = ""
    reply += "HTTP/1.1 #{header}\r\n"
    reply += "Content-Type: #{contentype}\r\n"
    reply += "Content-Length: #{content.length}\r\n"
    reply += "X-XSS-Protection: 1; mode=block\r\n"
    reply += "X-Content-Type-Options: nosniff\r\n"
    reply += "Connection: close\r\n"
    reply += "\r\n"
    reply += content
    return reply
  end

  def genRedirect(url)
    reply = ""
    reply += "HTTP/1.1 301 Moved Permanently\r\n"
    reply += "Location: #{url}\r\n"
    reply += "Connection: close\r\n"
    reply += "\r\n"
    return reply
  end

  def genError(code)
    reply = ""
    reply += "<html><head><title>#{code}</title></head><body><h1>#{code}</h1></body></html>"
    return reply
  end
  


  def getMIME(path)
    ext = path.split(".")[-1]
    # puts ext
    if @Exts.include?(ext)
      return "image/#{ext}"
    end
    # If ext js
    if ext == "js"
      return "application/javascript"
    end
    if ext == "css"
      return "text/css"
    end
    return "text/#{ext}"
  end

  attr_reader :dir, :errordir
end