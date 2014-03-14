# Bot用基本クラス
require 'logging.rb'
require 'tweet_context.rb'
require 'config.rb'

class Bot
	def initialize()
	    @log = Logging.new
	end
    
    # ツイート受信時の処理
    def on_tweet(tweet)
        @log.info("Tweet from #{status.user.screen_name}: #{status.text}")
        @log.info("Message: #{message}")

        filterd_tweet = filter_input_tweet(tweet)
        generate_response(input_data) if filterd_tweet
    end
    

    # ツイートを入力してフィルターする処理
    def filter_input_tweet(tweet)
        input_data = TweetContext.new(tweet)

        # RT || QT || 自分は無視
        return false if input_data.text.index("RT") || input_data.text.index("QT") || input_data.screen_name == MY_SCREEN_NAME

        return input_data
    end
    
    # 実際のリプライを生成する
    def generate_response(d)
        # サブクラスでオーバーライドする
    end

    # リプライを投稿
    def reply(text, tweet_id)
        
    end

    # ランダムに返す
    def rnd(message)
        length = message.length
        # 1つも要素がないなら返す
        if length < 1
            $log.warn("Dice called but array is null!")
            return ""
        elsif length == 1
            $log.warn("Dice called and only one!")
            return message
        end
        # 適当に選んで・・・
        messageArrayIndex = $random.rand(length-1)
        $log.debug("Dice selected: " + messageArrayIndex.to_s)
        # 返す
        return message[messageArrayIndex]
    end
end
