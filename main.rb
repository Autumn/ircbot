require 'cinch'
require 'open-uri'
require 'uri'
require 'json'
require 'yaml'
require 'sqlite3'

class Waifu
   attr_accessor :name, :series
   def initialize
      @@db = SQLite3::Database.new("waifu.db")
      count = @@db.execute("select count(*) from waifus")
      n = Random.rand(count[0][0]) + 1
      row = @@db.execute("select name, series from waifus where id = #{n}")
      @name = row[0][0]
      @series = row[0][1]
   end
end

if ARGV.length != 1
   abort "First argument must be a config file"  
else
    config = YAML::load(File.open(ARGV[0]))
end

bot = Cinch::Bot.new do
  configure do |c|
    c.server = config["server"]
    c.channels = config["channels"]
    c.nick = config["nick"]
    c.user = config["user"]
    c.host = config["host"]
    c.realname = config["realname"]
    c.idPassword= config["password"]
  end

  commandList = ["dango", "anime", "manga"]
  commandHelp = {
    'dango' => 'Summons a dango daikazoku of varying size. No options.',
    'anime' => 'Searches MAL\'s anime database for the requested string. Syntax :: .anime [resultNumber] <query> :: resultNumber defaults to 0 if omitted.',
    'manga' => 'Searches MAL\'s manga database for the requested string. Syntax :: .anime [resultNumber] <query> :: resultNumber defaults to 0 if omitted.'
  }

  on :connect do |m|
    target = Cinch::Target.new("NickServ", bot)
    target.msg("identify #{bot.config.idPassword}", notice = false)
  end

  on :message, /^.dango/ do |m|
    str = ""
    Random.rand(1..30).times {str += '(' + [" ' ' ", " '' ", "''", "' '"].sample + ')'}
    m.reply str
  end

  on :message, /^.(anime|manga) (\d+)? ?(.+)/ do |m, cmd, n, title|
    src = open("http://mal-api.com/#{cmd}/search?q=#{URI.escape(title)}").read
    search = JSON.parse(src, {})

    n = n.to_i
    if n <= 0 or n > search.length
        n = 0
    else
        n -= 1
    end

    if search != []

      query = search[n]
      accessUrl = "http://myanimelist.net/#{cmd}/#{query["id"]}"

      yearAired = ""
      if query["start_date"] != nil
        yearAired = "(" + query["start_date"].to_s.split('-')[0] + ")"    
      end
      m.reply ":: #{query["title"]} #{yearAired} :: #{query["members_score"]} :: #{accessUrl} :: #{n+1}/#{search.length} ::"
    else
      m.reply "No results found."
    end
  end

  on :message, /^.help ?(.+)?/ do |m, cmd|
    if cmd != nil
      m.reply "#{commandHelp[cmd]}"
    else
      m.reply "Available commands :: dango anime manga :: .help <command> for more information."
    end
  end

  on :message do |m|
    words = m.message.split(" ")
    words.each do |s|
      uri = URI::Parser.new.parse s
      if uri.class == URI::HTTP or uri.class == URI::HTTPS
        open(uri).read =~ /<title>(.*?)<\/title>/
        if $1 != nil
          m.reply "[URI] #{$1}"
        end
      end
    end
  end


  on :message, /^\.waifu$/ do |m|
    waifu = Waifu.new
    m.reply "#{m.user}, your waifu is #{waifu.name} (#{waifu.series})"
  end

  on :message, /^\.waifu-rps/ do |m|
    one = Waifu.new
    two = Waifu.new
    m.reply "Battle Start! #{one.name} (#{one.series}) vs. #{two.name} (#{two.series})!"

    moves = [[0, "rock"], [1, "paper"], [2, "scissors"]]
    one_move = moves.sample
    two_move = moves.sample

    resp = "#{one.name} throws #{one_move[1]}! #{two.name} throws #{two_move[1]}!"
    

    winner = (3 + one_move[0] - two_move[0]) % 3;
    if winner == 0
      m.reply "#{resp} It's a draw!"
    elsif winner == 1
      m.reply "#{resp} #{one.name} wins!"
    else
      m.reply "#{resp} #{two.name} wins!"
    end
  end

end

bot.start
