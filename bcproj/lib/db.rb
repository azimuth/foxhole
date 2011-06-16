require 'active_record'
  class DB
    def DB.initdb
      # set up active record
      ActiveRecord::Base.establish_connection(
        :adapter => "sqlite3",
        :database => "./db/bcproj.sqlite3"
      )
    end
  end
