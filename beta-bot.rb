# coding: utf-8

=begin

Tipmona bot v0.01

- Donation welcome -
  BTC: 15bi3u4pFxBA3fMrsXsNn645igW7xSJmny
  LTC: Ld5ojxT92egBsa2nJiK6DdzBB1Hoh5r7o3
 MONA: MSEFCyitaSrTKgp4gdGPhMxxY5ZmBx9wbg

- Thank you for your support! -


MIT License (MIT)

Copyright (c) 2014 Palon http://rix.xii.jp/

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

=end

# そろそろきっちりクラスにしたい。

require './bitcoin_rpc.rb'
require './multi_io.rb'
require 'rubygems'
require 'net/https'
require 'twitter'
require 'oauth'
require 'json'
require 'pp'
require 'sqlite3'
require 'active_record'
require 'bigdecimal'
require 'logger'
require 'yaml'

require './beta-config.rb'


# DB接続
ActiveRecord::Base.configurations = YAML.load_file('database.yml')
ActiveRecord::Base.establish_connection("production")

class User < ActiveRecord::Base
end

$twitter = Twitter::REST::Client.new do |config|
  config.consumer_key        = CONSUMER_KEY
  config.consumer_secret     = CONSUMER_SECRET
  config.access_token         = ACCESS_TOKEN
  config.access_token_secret  = ACCESS_TOKEN_SECRET
end

log_file = File.open("bot.log", "a")
log_file.sync = true


$log = Logger.new(MultiIO.new(STDOUT, log_file), 5)

$monacoind = BitcoinRPC.new("http://#{COIND_USERNAME}:#{COIND_PASSWORD}@#{COIND_ADDRESS}:#{COIND_PORT}")

$last_faucet = Hash::new

$random = Random.new()

=begin
TweetStream.configure do |config|
end
=end

client = Twitter::Streaming::Client.new do |config|
  config.consumer_key        = CONSUMER_KEY
  config.consumer_secret     = CONSUMER_SECRET
  config.access_token         = ACCESS_TOKEN
  config.access_token_secret  = ACCESS_TOKEN_SECRET
end
	
def dice(message)
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


def isjp(username)
	l = $twitter.user(username).lang
	$log.debug("User language: #{l}")

	if l.index("ja")
		return true
	else
		return false
	end
end

def postTwitter(text, statusid = false)
  begin
    if statusid
	    $twitter.update(text, :in_reply_to_status_id => statusid)
	else
	    $twitter.update(text)
    end
  rescue Timeout::Error, StandardError => exc
    $log.error("Error while posting: #{exc}: [text]#{text}")
  else
    $log.info("Posted: #{text}")
  end
end

def getps()
    return "。" * $random.rand(5)
end

def get_user(screen_name)
    user = User.where(:screen_name => screen_name).first
    if !user.blank?
        return user
    else
        $log.debug("Not found in DB, create...")
        user = User.create(
            :screen_name => screen_name,
            :donated => 0,
            :affection => 50,
            :give_at => 0
        )
        return user
    end
end

=begin
# 稼働時の処理（ここではサーバ接続したことを表示）
client.on_inited do
  $log.info('Connected to twitter')
end

#接続時に送られるフォロワーリストを受けたときの処理
client.on_friends do |friends|
  $log.info("Recieved a friends list")
# postTwitter("@palon7 Tipmona " + $ver + " ready")
end

#ツイート削除を含むメッセージを受けたときの処理
client.on_delete do |status_id, user_id|
  $log.info("Recieve a delete message / status_id: #{status_id}, user_id: #{user_id}")
end
=end

#ツイートなどを含むメッセージを受けたときの処理
def on_tweet(status)
  if !status.text.index("RT") && !status.text.index("QT") && status.user.screen_name != MY_SCREEN_NAME
 	#   checkfollow()
    $log.info("Tweet from #{status.user.screen_name}: #{status.text}")

	if !status.text.index(MY_SCREEN_NAME)
		return
	end

    message = status.text.gsub(/@#{MY_SCREEN_NAME} ?/, "")
    $log.info("Message: #{message}")

	username = status.user.screen_name
	account = "tipmona-" + username.downcase
	
	pp status
	# ステータスID
	to_status_id = status.id
	
	return if username == MY_SCREEN_NAME
	
    userdata = get_user(username)
    pp userdata

	# トランザクション処理
	
    case message
	when /RT.*@.*/
		$log.debug("Retweet. Ignore.")
	when /giveme|give me/
        # 自動ツイート系対策（できてるか自信ない）
        if status.source =~ /(twittbot(\.net)?|EasyBotter|IFTTT|Twibow|MySweetBot|BotMaker|rakubo2|Stoome|twiroboJP|劣化コピー|ツイ助|makebot)/
		   	return
        end
		$log.info("-> Giving...")
		BAN_USER.each do |v|
			if username == v
				$log.info("-> Banned user.")
				postTwitter("@#{username} あなたのアカウントはfaucet機能を停止されています。ご不明な点があれば@palon7へご連絡ください。", to_status_id)
			end
		end
		# Tweet count
		if $twitter.user(username).statuses_count < 25
			$log.info("-> Not enough tweet!");
			if isjp(username)
				postTwitter(dice([
					"@#{username} ごめんなさい、まだあなたのアカウントのツイート数が少なすぎるようです#{getps()} Twitterをもっと使ってからもう一度お願いします！"
				]), to_status_id)
			else
				postTwitter("@#{username} Your account hasn't much tweet#{getps()}", to_status_id)
			end
			return
		end

		r_need_time = $twitter.user(username).created_at + (24 * 60 * 60 * 14)
		pp r_need_time
		if r_need_time > Time.now
			$log.info("-> Not enough account created time!");
			if isjp(username)
				postTwitter(dice([
					"@#{username} ごめんなさい、まだあなたはアカウントを作成してから二週間以上経ってないみたいです#{getps()}"
				]), to_status_id)
			else
				postTwitter("@#{username} Your account must be created at more than 2 weeks ago#{getps()}", to_status_id)
			end
			return
		end		
		
        amount = (10 + $random.rand(65).to_f) / 100
		$log.debug("Amount: #{amount}")
		
		if $last_faucet[username] == nil || $last_faucet[username] + (24 * 60 * 60) < Time.now
			fb = $monacoind.getbalance("tipmona-mona_faucet")
			if fb < 1
				$log.info("-> Not enough faucet pot!")
				if isjp(username)
					postTwitter(dice([
						"@#{username} ごめんなさい、配布用ポットの中身が足りません＞＜ @mona_faucetに送金してもらえると嬉しいですっ！",
						"@#{username} ごめんなさい、配布用ポットにMONAが入ってないみたいです＞＜ @mona_faucetに送金してもらえると嬉しいですっ！",
						"@#{username} ごめんなさい、配布用ポットの中身がもうありません＞＜ @mona_faucetに送金してもらえると嬉しいですっ！",
						"@#{username} ごめんなさい、配布用ポットの中身がないみたいですっ＞＜ @mona_faucetに送金してもらえると嬉しいですっ！"
					]), to_status_id)
				else
					postTwitter("@#{username} Sorry, there is no more MONA in faucet (><) Please tip to @mona_faucet#{getps()}", to_status_id)
				end
				return
			end
			
			$monacoind.move("tipmona-mona_faucet", account, amount)
			$log.info("-> Done.")
			if isjp(username)
				postTwitter(dice([
					"@#{username} さんに#{amount}Monaプレゼントっ！",
					"@#{username} さんに#{amount}Monaをプレゼント！",
					"@#{username} さんに#{amount}Monaをプレゼントしましたっ！",
					"@#{username} さんに#{amount}Monaプレゼントしました！！"
				]), to_status_id)
			else
				postTwitter("Present for @#{username} -san! Sent #{amount}Mona!", to_status_id)
			end
			$last_faucet[username] = Time.now
		else
			$log.info("-> Already received in last 24 hours!")
			if isjp(username)
				postTwitter(dice([
					"@#{username} まだ最後の配布から24時間経ってないようです・・・ごめんなさい！",
					"@#{username} まだ最後の配布から24時間経ってないようです・・・・ごめんなさい！",
					"@#{username} まだ最後の配布から24時間経ってないみたいです・・・ごめんなさい！",
					"@#{username} まだ最後の配布から24時間経ってないみたいです・・・・ごめんなさい！"
				]), to_status_id)
			else
				postTwitter("@#{username} You have already received MONA in the last 24 hours#{getps()}", to_status_id)
			end
		end
	when /(Follow|follow|フォロー|ふぉろー)して/
		$log.info("Following #{username}...")
		pp $twitter.follow(username)
		$log.info("-> Followed.")
		postTwitter("@#{username} をフォローしました！", to_status_id)
	when /balance/
		$log.info("Check balance of #{username}...")
		balance = $monacoind.getbalance(account,6)
		all_balance = $monacoind.getbalance(account,0)
		$log.info("-> #{balance}MONA (all: #{all_balance}MONA)")
		if isjp(username)
			$log.debug("Rolling dice")
begin
			status = dice([
				"@#{username} さんの残高は #{balance} Monaです！ (confirm中残高との合計: #{all_balance} Mona)",
				"@#{username} さんの残高は #{balance} Monaですよ！ (confirm中残高との合計: #{all_balance} Mona)",
				"@#{username} さんのアカウントには #{balance} Monaあります！ (confirm中残高との合計: #{all_balance} Mona)",
				"@#{username} さんのアカウントには #{balance} Monaありますよ！ (confirm中残高との合計: #{all_balance} Mona)",
				"@#{username} さんの残高は #{balance} Monaですっ！ (confirm中残高との合計: #{all_balance} Mona)",
				"@#{username} さんの残高は #{balance} Monaですよっ！ (confirm中残高との合計: #{all_balance} Mona)"
			])
			$log.debug("Send: @#{status}")
			postTwitter(status,to_status_id)
rescue
 		   $log.error("#{exc}: [text]#{text}")
end   
		else
			postTwitter("@#{username} 's balance is #{balance} Mona#{getps()} (Total with confirming balance: #{all_balance} Mona)", to_status_id)
		end
	when /deposit/
		$log.info("Get deposit address of #{username}...")
		address = $monacoind.getaccountaddress(account)
		$log.info("-> #{account} = #{address}")
		if isjp(username)
			postTwitter(dice([
				"@#{username} #{address} にMonacoinを送金してください！",
				"@#{username} #{address} にMonacoinを送ってください！",
				"@#{username} #{address} にMonacoinを送金してくださいっ！",
				"@#{username} #{address} にMonacoinを送ってくださいっ！"
			]), to_status_id)
		else
			postTwitter("@#{username} Please send MONA to #{address}", to_status_id)
		end
	when /message( |　)(.*)/
		if username == "palon7"
			puts "get?"
			postTwitter("管理者からの伝言です！ 「" + $2 + "」")
		end
	when /(withdraw)( |　)+(([1-9]\d*|0)(\.\d+)?)( |　)+(M[a-zA-Z0-9]{26,33}) ?/
		$log.info("Withdraw...")
		amount = $3.to_f
		tax = 0.005
		total = amount + tax
		address = $7
		balance = $monacoind.getbalance(account,6)
		
		$log.info("-> Withdraw #{amount}Mona + #{tax}Mona from @#{username}(#{balance}Mona) to #{address}")
		
		# 残高チェック
		if balance < total
			$log.info("-> Not enough MONA. (#{balance} < #{total})")
			if isjp(username)
				postTwitter(dice([
	        		"@#{username} ごめんなさい、残高が足りないようです#{getps()} 引き出しには0.005Monaの手数料がかかることにも注意してください！ (現在#{balance}Mona)",
	        		"@#{username} ごめんなさい、残高が足りません＞＜ 引き出しには0.005Monaの手数料がかかることにも注意してください！ (現在#{balance}Mona)",
	        		"@#{username} ごめんなさい、残高が足りないみたいです#{getps()} 引き出しには0.005Monaの手数料がかかることにも注意してください！ (現在#{balance}Mona)"
				]),to_status_id)
			else
	        	postTwitter("@#{username} Not enough balance. Please note that required 0.005Mona fee when withdraw#{getps()}(Balance:#{balance}Mona)", to_status_id)
			end
			return
		end
		
		# アドレスチェック
		validate = $monacoind.validateaddress(address)
		if !validate['isvalid']
			$log.info("-> Invalid address")
			if isjp(username)
				postTwitter("@#{username} ごめんなさい、アドレスが間違っているみたいです#{getps()}", to_status_id)
			else
				postTwitter("@#{username} Invalid address#{getps()}",to_status_id)
			end
			puts "Invalid address."
		end

		# go
		$log.info("-> Sending...")
		txid = $monacoind.sendfrom(account,address,amount)

		$log.info("-> Checking transaction...")
		tx = $monacoind.gettransaction(txid)

		if tx
			fee = tx['fee']
			$log.info("-> TX Fee: #{fee}")
		else
			fee = 0
			$log.info("-> No TX Fee.")
		end

		$monacoind.move(account,"taxpot",tax + fee)
		potsent = tax + fee
		$log.info("-> Fee sent to taxpot: #{potsent}Mona (Real fee: #{fee}Mona)")
		if isjp(username)
			postTwitter(dice([
				"@#{username} Monacoinを引き出しました！http://abe.monash.pw/tx/#{txid}",
				"@#{username} さんのMonacoinを引き出しました！http://abe.monash.pw/tx/#{txid}",
				"@#{username} Monacoinを引き出しましたっ！http://abe.monash.pw/tx/#{txid}"
			]),to_status_id)
		else
			postTwitter("@#{username} Withdraw complete. http://abe.monash.pw/tx/#{txid}", to_status_id)
		end
    when /debuginfo/
        postTwitter("@#{username} Donated: #{userdata.donated} Affection:#{userdata.affection}")
    when /(tip)( |　)+@([A-z0-9_]+)( |　)+(([1-9]\d*|0)(\.\d+)?)/
		$log.info("Sending...")
		# 情報取得
		balance = $monacoind.getbalance(account,6)	# 残高
		from = username   # 送信元
        to = $3           # 送信先
        amount = $5.to_f  # 金額

		$log.info("-> Send #{amount}mona from @#{from} to @#{to}")

		# 額が0より小さかったら無視する
		return if amount < 0


        # 残高チェック
		if balance < amount
			$log.info("-> Not enough Mona. (#{balance} < #{amount})")
			if isjp(username)
		        postTwitter(dice([
					"@#{username} ごめんなさい、残高が足りないみたいです＞＜ 6confirmされるまで残高が追加されないことにも注意してください！(現在の残高:#{balance}Mona)",
					"@#{username} ごめんなさい、残高が足りないみたいです・・・ 6confirmされるまで残高が追加されないことにも注意してください！(現在の残高:#{balance}Mona)",
					"@#{username} ごめんなさい、残高が足りないようです＞＜ 6confirmされるまで残高が追加されないことにも注意してください！(現在の残高:#{balance}Mona)",
					"@#{username} ごめんなさい、残高が足りないようですっ＞＜ 6confirmされるまで残高が追加されないことにも注意してください！(現在の残高:#{balance}Mona)",
					"@#{username} ごめんなさい、残高が足りないようです・・ 6confirmされるまで残高が追加されないことにも注意してください！(現在の残高:#{balance}Mona)"
				]), to_status_id)
			else
	        	postTwitter("@#{username} Not enough balance. Please note that your balance apply when after 6 confirmed.#{getps()}(Balance:#{balance}Mona)", to_status_id)
			end
	    	return
        end
		
		# 送信先ユーザの存在をチェック
		begin
			# ユーザ情報を取得してみる
			$twitter.user(to)
		rescue Twitter::Error::NotFound # NotFoundなら
			# エラーメッセージ送信
			postTwitter("@#{username} 申し訳ありません！#{to}というユーザー名は存在しないようです。", to_status_id)
			# 送金をスキップする
			return
		end

		# moveで送る
		to_account = "tipmona-" + to.downcase
		$monacoind.move(account,to_account,amount)
		$log.info("-> Sent.")
		if isjp(to)
			if to_account == "tipmona-mona_faucet" || to_account == "tipmona"
                if to_account == "tipmona"
                    userdata.affection = userdata.affection + (ammount * 1).ceil
                else
                    userdata.donated = userdata.donated + amount
                    userdata.affection = userdata.affection + (ammount * 0.5).ceil
                end
                userdata.save
				if amount > 5
					postTwitter(dice([
						"@#{from} わぁ・・・こんなにたくさんありがとうございます！ #{amount}monaを寄付用ポットにお預かりしました！",
						"@#{from} わぁ・・・こんなにたくさんありがとうございますっ！ #{amount}monaを寄付用ポットにお預かりしました！",
						"@#{from} こんなにいいんですか！？ありがとうございます！ #{amount}monaを寄付用ポットにお預かりしました！",
						"@#{from} こんなにいいんですか！？ありがとうございますっ！ #{amount}monaを寄付用ポットにお預かりしました！",
						"@#{from} こんなにいっぱい・・・ありがとうございます！ #{amount}monaを寄付用ポットにお預かりしました！",
						"@#{from} こんなにいっぱい・・・ありがとうございますっ！ #{amount}monaを寄付用ポットにお預かりしました！",
						"@#{from} すごい・・・本当にありがとうございます！ #{amount}monaを寄付用ポットにお預かりしました！",
						"@#{from} すごい・・・本当にありがとうございますっ！ #{amount}monaを寄付用ポットにお預かりしました！",
						"@#{from} わぁ・・・ありがとうございます！大好きです！ #{amount}monaを寄付用ポットにお預かりしました！"
					]), to_status_id)
				else
					postTwitter(dice([
						"@#{from} ありがとうございます！ #{amount}monaを寄付用ポットにお預かりしました！",
						"@#{from} わー、ありがとうございます！ #{amount}monaを寄付用ポットにお預かりしました！",
						"@#{from} ありがとうございます！ #{amount}monaを寄付用ポットにお預かりしました！",
						"@#{from} わー、ありがとうございます！ #{amount}monaを寄付用ポットにお預かりしました！",
						"@#{from} ありがとうございます！ #{amount}monaを寄付用ポットにお預かりしましたっ！",
						"@#{from} わー、ありがとうございます！ #{amount}monaを寄付用ポットにお預かりしましたっ！",
						"@#{from} ありがとうございます！ #{amount}monaを寄付用ポットにお預かりしましたっ！",
						"@#{from} わー、ありがとうございます！ #{amount}monaを寄付用ポットにお預かりしましたっ！"
					]), to_status_id)
				end
			else
				postTwitter(dice([
					"@#{from} さんから @#{to} さんにお届け物ですっ！ つ[#{amount}mona]",
					"@#{from} さんから @#{to} さんにお届け物ですよっ！ つ[#{amount}mona]",
					"@#{from} さんから @#{to} さんにお届け物です！ つ[#{amount}mona]",
					"@#{from} さんから @#{to} さんにお届け物ですよー！ つ[#{amount}mona]",
					"@#{from} さんの#{amount}monaを @#{to} さんにどんどこわっしょーいっ",
					"@#{from} さんの#{amount}monaを @#{to} さんにどんどこわっしょーい！",
					"@#{from} さんの#{amount}monaを @#{to} さんにどんどこわっしょーいっ！"
				]), to_status_id)
			end
		else
			postTwitter(dice([
				"@#{from} -san to @#{to} -san! sent #{amount}mona.",
				"From @#{from} -san to @#{to} -san! sent #{amount}mona.",
				"@#{from} -san's #{amount}mona sent to @#{to} -san!"
			]),to_status_id)
		end
	when /((結婚|けっこん)し(て|よう))|marry ?me/
        if userdata.affection >= 55
            postTwitter(dice([
                "@#{username} お気持ちは嬉しいですが、ごめんなさい…",
                "@#{username} 嬉しいけど、ごめんなさい。"
            ]), to_status_id)
        else
    		postTwitter(dice([
    			"@#{username} ごめんなさい！",
    			"@#{username} ごめんなさい・・・"
    		]), to_status_id)
        end
	end
  end
end

def checkfollow()
begin
	$log.debug("Check follow...")


	pp "1"
	follower_ids = []
	pp "1.1"
	$twitter.follower_ids("tipmona").each do |id|
		pp "1.2"
		follower_ids.push(id)
	end
	
	pp "2"

	friend_ids = []
	$twitter.friend_ids("tipmona").each do |id|
		friend_ids.push(id)
	end
	
	pp 3
	
	if follower_ids == friend_ids
		return
	end
	
	pp 4

	fol = follower_ids - friend_idsgin
	$twitter.follow(fol)
	
	$log.debug("Done...")
rescue
    puts "Error while sending: #{exc}: [text]#{text}"
end
end

#on設定を終えたあとにclient.userstreamメソッドを稼働させる
client.user do |object|
    case object
    when Twitter::Tweet
        on_tweet(object)
    end
 end
=begin
begin
client.userstream do |object|
end
rescue
    puts "Error while sending: #{exc}: [text]#{text}"
end   
=end


=begin
class Bot

  MY_SCREEN_NAME = "tipmona"

  BOT_USER_AGENT = "monacoin tip bot @#{MY_SCREEN_NAME}"

  def initialize
    @q = Queue.new
    Thread.start do
	  client.user do |object|
	    puts "recieve a message / class: #{object.class}"
	    case object
	    when Twitter::Tweet
	      @q.push(object.text)
	    end
	  end
	end

    puts "Bot System is ready"	
  end

  def run
    loop do
      unless @q.empty?
        puts @q.pop
      end
    end
  end
end
=end
