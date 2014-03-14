require 'bot.rb'

class BotTipmona < Bot

    def generate_response(d)
        
    end

    def is_banned?(d)
        # 自動ツイート系サービスならtrue
        if BAN_CLIENT.find {|v|
                if v.is_a?(Regexp)
                    d.source =~ v
                else
                    d.source.index(">#{v}<") != nil
                end
            }
            # true
            @log.info("@#{username}")
            return true
        end

		BAN_USER.each do |v|
	        if username == v
        		@log.info("@#{username} is Banned user.")
		    end
        end
    end
end
