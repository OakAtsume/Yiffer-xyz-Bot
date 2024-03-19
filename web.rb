require_relative("src/log4bot")
require_relative("src/backend")




Logs = Log4Bot.new("logs")
Web = Backend.new(8080)
Gen = Responder.new("web", "web/error")

Web.on(:request) do |host, data, client|
    Logs.log("#{host} #{data[:method]} #{data[:path]} #{data[:headers]["User-Agent"]}", :info)
    if File.exist?("#{Gen.dir}#{data[:path]}") && !File.directory?("#{Gen.dir}#{data[:path]}")
        client.write(
            Gen.gen(
                "200 OK",
                Gen.getMIME(data[:path]),
                File.read("#{Gen.dir}#{data[:path]}")
            )
        )
    else
        Logs.log("404 Not Found: #{data[:path]}", :warn)
        client.write(
            Gen.gen(
                "404 Not Found",
                "text/html",
                File.read("#{Gen.errordir}/404.html")
            )
        )
    end
    client.close
end

Web.on(:error) do |e|
    Logs.log("Error: #{e}", :error)
end

Web.on(:onBlockedRequest) do |host, data, client|
    Logs.log("Processing blocked request from #{host} #{data[:method]} #{data[:path]} #{data[:headers]["User-Agent"]}", :icewall)
    # Simply send a 403 Forbidden and a page saying "Ooops~ You've been caught! if this is a mistake, please contact the administrator."
    client.write(
        Gen.gen(
            "403 Forbidden",
            "text/html",
            File.read("#{Gen.errordir}/blocked.html")
        )

    )
    client.close
end

Web.on(:onIceBlock) do |host, reason|
    Logs.log("blocked #{host} for `#{reason}`", :security)
end

Web.start