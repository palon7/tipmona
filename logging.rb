require 'logger'
require './multi_io.rb'

class Logging
    def initialize(filename = "tipmona.log")
        # ログ用ファイルを開く
        @log_file = File.open(filename, "a")
        @log_file.sync = true   # 書き込みと同時に反映させるようにする
        
        # Loggerを作成
        @logger = Logger.new(MultiIO.new(STDOUT, @log_file), 5) # 標準出力とlog_fileに同時に出力する
        @logger.level = Logger::INFO
        
        @logger.debug("Logger started")
        return @logger
    end
end
