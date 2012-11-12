require 'fileutils'

class DB

  SUPPORTED_DATABASES = [
                         {
                           :pattern => /jdbc:mysql/,
                           :name => "MySQL"
                         },
                         {
                           :pattern => /jdbc:derby/,
                           :name => "Apache Derby"
                         }
                        ]

  def self.connect
    if not @pool

      if !AppConfig[:allow_unsupported_database]
        check_supported(AppConfig[:db_url])
      end

      begin
        Log.info("Connecting to database: #{AppConfig[:db_url]}")
        pool = Sequel.connect(AppConfig[:db_url],
                              :max_connections => AppConfig[:db_max_connections],
                              :test => true,
                              #:loggers => [Logger.new($stderr)]
                              )

        # Test if any tables exist
        pool[:schema_info].all

        @pool = pool
      rescue
        Log.error("DB connection failed: #{$!}")
      end
    end
  end


  def self.connected?
    not @pool.nil?
  end


  def self.open(transaction = true)
    last_err = false

    5.times do
      begin
        if transaction
          @pool.transaction do
            return yield @pool
          end

          # Sometimes we'll make it to here.  That means we threw a
          # Sequel::Rollback which has been quietly caught.
          return
        else
          return yield @pool
        end


      rescue Sequel::DatabaseDisconnectError => e
        # MySQL might have been restarted.
        last_err = e
        Log.info("Connecting to the database failed.  Retrying...")
        sleep(3)


      rescue Sequel::DatabaseError => e
        if e.wrapped_exception.getSQLState =~ /^40/
          # Transaction was rolled back, but we can retry
          sleep 1
        else
          raise e
        end
      end

    end

    if last_err
      Log.error("Failed to connect to the database")
      Log.exception(last_err)

      raise "Failed to connect to the database: #{last_err}"
    end
  end


  # Yeesh.
  def self.is_integrity_violation(exception)
    return exception.wrapped_exception.cause.getSQLState() =~ /^23/
  end


  def self.disconnect
    @pool.disconnect
  end


  def self.check_supported(url)
    if !SUPPORTED_DATABASES.any? {|db| url =~ db[:pattern]}

      msg = <<eof

=======================================================================
UNSUPPORTED DATABASE
=======================================================================

The database listed in your configuration:

  #{url}

is not officially supported by ArchivesSpace.  Although the system may
still work, there's no guarantee that future versions will continue to
work, or that it will be possible to upgrade without losing your data.

It is strongly recommended that you run ArchivesSpace against one of
these supported databases:

eof

      SUPPORTED_DATABASES.each do |db|
        msg += "  * #{db[:name]}"
      end

      msg += "\n"
      msg += <<eof

To ignore this (very good) advice, you can set the configuration option:

  AppConfig[:allow_unsupported_database] = true


=======================================================================

eof

      Log.error(msg)

      raise "Database not supported"
    end
  end


  def self.backups_dir
    File.join(AppConfig[:data_directory], "demo_db_backups")
  end


  def self.expire_backups

    backups = []
    Dir.foreach(backups_dir) do |filename|
      if filename =~ /^demo_db_backup_[0-9]+_[0-9]+$/
        backups << File.join(backups_dir, filename)
      end
    end

    victims = backups.sort.reverse.drop(AppConfig[:demo_db_backup_number_to_keep])

    victims.each do |backup_dir|
      # Proudly paranoid
      if File.exists?(File.join(backup_dir, "archivesspace_demo_db", "BACKUP.HISTORY"))
        Log.info("Expiring old backup: #{backup_dir}")
        FileUtils.rm_rf(backup_dir)
      else
        Log.warn("Too cowardly to delete: #{backup_dir}")
      end
    end
  end


  def self.demo_db_backup
    # Timestamp must come first here for filenames to sort chronologically
    this_backup = File.join(backups_dir, "demo_db_backup_#{Time.now.to_i}_#{$$}")

    Log.info("Writing backup to '#{this_backup}'")

    @pool.pool.hold do |c|
      cs = c.prepare_call("CALL SYSCS_UTIL.SYSCS_BACKUP_DATABASE(?)")
      cs.set_string(1, this_backup.to_s)
      cs.execute
      cs.close
    end

    expire_backups
  end

end
