require 'discordrb'
require 'feedjira'
require 'time'
require 'httparty'

# Bot behaviour
REFRESH_PERIOD = ENV['REFRESH_PERIOD'].freeze
PREFIX = ENV['DISCORD_PREFIX'].freeze

# Discord settings
TOKEN = ENV['DISCORD_TOKEN'].freeze

# Forum settings
BASE_URL = ENV['FORUM_BASE_URL'].freeze

bot = Discordrb::Commands::CommandBot.new token: TOKEN, prefix: PREFIX
at_exit { bot.stop }

bot.command :set_channel do |event|
  @channel = event.channel
  event = "Set channel to #{@channel.name}."
end

# True means bot.run is non-blocking and execution continues past this line
bot.run(true)

# Download feed file, parse, filter out entries that occured before last update and order by publication date
def get_feed
  xml = HTTParty.get("#{BASE_URL}/app.php/feed").body
  entries = Feedjira.parse(xml).entries
  entries.select!{ |e| e.published > Time.now.utc - REFRESH_PERIOD}
  entries.sort_by{ |e| e.published }
end

# Build one message out of all new events
def notify(entries)
  message = ''
  entries.each do |e|
    message << "**#{e.author}** posted #{e.title}\n*#{e.url}*\n\n"
  end
  @channel.send_message(message)
end

# Check every minute for new events and then build messages
loop do
  if @channel
    new_entries = get_feed
    notify(new_entries)
    sleep(REFRESH_PERIOD)
  end
end
