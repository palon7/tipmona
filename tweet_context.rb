# ツイートに対するコンテクスト
class TweetContext
    attr_reader :status         # 入力tweet
    attr_reader :user           # user
    attr_reader :screen_name    # screen_name
    attr_reader :id             # id
    attr_reader :text           # text

    def initialize(tweet)
        @status = tweet
        @user = @input_tweet.user
        @screen_name = @user.screen_name
        @text = tweet.text
    end
end
