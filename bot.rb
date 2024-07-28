require("json")
require("net/http")
require("uri")
require("cgi/escape")

class YifferBot
  def initialize(path, maxThreads = 6)
    @api = {
      :page => "https://yiffer.xyz/api/comicsPaginated",
      :main => "https://yiffer.xyz/api",
      :image => "https://static.yiffer.xyz/comics",
    }
    @maxThreads = maxThreads
    @path = path
    @indexFile = File.join(@path, "index.json")
    @index = []
    @threads = []
  end

  # def downloadComic(comicName)

  #     # Download pages using threads
  #     pages = comic["numberOfPages"]
  #     threads = []

  def downloadComic(comicName)
    name = comicName
    comic = retreatComic(comicName)
    @index.push(
      {
        :name => comic["name"],
        :author => comic["artist"],
        :type => formatType(comic["tag"]),
        :tags => comic["keywords"],
        :pages => comic["numberOfPages"],
        :updated => comic["updated"],
      }
    )
    # Write
    File.write(@indexFile, JSON.pretty_generate(@index))
    # If folder doesn't exist, create it
    folder = File.join(@path, comic["name"])
    if !File.directory?(folder)
      Dir.mkdir(folder)
    end
    # Download cover
    cover = retreatCover(comicName)
    downloadBot(cover, File.join(folder, "thumbnail.webp"))
    # ... existing code ...

    # Download pages using threads
    pages = comic["numberOfPages"]
    threads = []

    # Calculate the number of threads needed based on the maxThreads limit
    num_threads = [pages, @maxThreads].min

    # Calculate the number of pages per thread
    pages_per_thread = (pages.to_f / num_threads).ceil
    
    # calculate the estimated time
    estimated_time = (pages_per_thread / 2) * num_threads
    # Format into hours/minutes/seconds
    hours = estimated_time / 3600
    minutes = (estimated_time % 3600) / 60
    seconds = estimated_time % 60
    puts("Estimated time: #{hours}:#{minutes}:#{seconds}")


    # Spawn a thread for each page
    num_threads.times do |i|
      start_page = i * pages_per_thread + 1
      end_page = [start_page + pages_per_thread - 1, pages].min
      id = i + 1
      threads << Thread.new(start_page, end_page) do |start_page, end_page|
        localId = id
        (start_page..end_page).each do |page|
          # Download page logic here
          page_url = retreatPage(comicName, page)
          downloadBot(page_url, File.join(folder, "#{formatNum(page)}.jpg"))
          puts("(#{name}) Downloaded (#{page}/#{pages}) : #{((page.to_f / pages) * 100).round(2)}% : Thread #{localId}")
        end
      end
    end

    # Wait for all threads to finish
    threads.each(&:join)
  end

  def retreatCollection(page = 1)
    uri = URI.parse("#{@api[:page]}?page=#{page}&order=updated")
    response = Net::HTTP.get_response(uri)
    return JSON.parse(response.body)
  end

  def retreatComic(comicName)
    uri = URI.parse("#{@api[:main]}/comics/#{encode(comicName)}")
    response = Net::HTTP.get_response(uri)
    return JSON.parse(response.body)
  end

  def retreatCover(comicName)
    return "#{@api[:image]}/#{encode(comicName)}/thumbnail.webp"
  end

  def retreatPage(comicName, page)
    return "#{@api[:image]}/#{encode(comicName)}/#{formatNum(page)}.jpg"
  end

  def formatType(type)
    case type
    when "MM"
      type = "Male with Male"
    when "FF"
      type = "Female with Female"
    when "MF"
      type = "Male with Female"
    when "F"
      type = "Female"
    when "M"
      type = "Male"
    when "I"
      type = "Intersex"
    when "G"
      type = "Group"
    when "MF+"
      type = "Male with Female(s)"
    else
      type = type
    end
    return type
  end

  def downloadBot(url, path)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri)
    request["Cookie"] = "theme=light; hasConsented=1"
    response = http.request(request)
    File.write(path, response.body)
  end
  def lastUpdateFor(comicName)
    # Return last update for comic
    comic = retreatComic(comicName)
    return comic["updated"]
  end
  def encode(str)
    return URI.encode_uri_component(str)
  end
  def formatNum(num)
    return num.to_s.rjust(3, "0")
  end
  attr_reader :path
end

bot = YifferBot.new("comics/")
# Pages
pages = 100 # 100 pages
# Download comics
pages.times do |i|
  collection = bot.retreatCollection(i + 1)
  collection["comics"].each do |comic|
    # Check if comic is already downloaded
    if File.directory?(File.join(bot.path, comic["name"]))
      # Check if comic is updated
      if bot.lastUpdateFor(comic["name"]) == comic["updated"]
        puts("Skipped #{comic["name"]} : Already downloaded and No updates")
        next
      end
    end

    puts('> Downloading comic: ' + comic["name"])
    bot.downloadComic(comic["name"])
  end
end
