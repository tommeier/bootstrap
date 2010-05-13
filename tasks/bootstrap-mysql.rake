namespace :db do

  desc "Reset application to past SQL point"
  task :reset_app => :environment do
    puts "===================================================\n"
    puts "==         Rake - db:reset_app                   ==\n"
    puts "===================================================\n"

    #Check for any bootstrap sql file to load
    bootstrap_location = File.join(RAILS_ROOT, 'db', 'bootstrap')

    sql_file_location = ENV['file'] || File.join(bootstrap_location, 'bootstrap_data.sql')

    if File.exists?(sql_file_location)

      puts "Dropping database tables...\n"
      Rake::Task['db:drop'].reenable
      Rake::Task['db:drop'].invoke

      puts "Creating database tables...\n"
      Rake::Task['db:create'].reenable
      Rake::Task['db:create'].invoke

      puts "Loading database dump...\n"
      Rake::Task['db:database_load'].reenable
      Rake::Task['db:database_load'].invoke

      puts "\n***** Database Loaded... *****\n\n"

      migrator = ActiveRecord::Migrator.new(:up, "db/migrate")

      if migrator && migrator.current_migration && migrator.current_migration.filename
        last_migration_file = migrator.current_migration.filename

        puts "** Loading migrations since #{last_migration_file} -->"
      else
        puts "** Error - Unable to find the current migration file. Most likely cause is the database has migrations loaded that are beyond the code base. Please update the codebase."
        puts "** Attempting to run migration tasks."
      end
      Rake::Task['db:migrate'].reenable
      Rake::Task['db:migrate'].invoke
    else
      raise "Error - Unable to find sql file to load : #{sql_file_location}"
    end

    puts "===================================================\n"
    puts "==        Rake - db:reset_app completed          ==\n"
    puts "===================================================\n"
  end


  desc "Dump the current database to an SQL file"
  task :database_dump do
    load 'config/environment.rb' if !Object.const_defined?(:ActiveRecord)
    config = ActiveRecord::Base.configurations

    case config[RAILS_ENV]["adapter"]
    when 'mysql'
      ActiveRecord::Base.establish_connection(config[RAILS_ENV])

      raise "Please ensure your config/database.yml file has a host for the database. eg. host = localhost"  if config[RAILS_ENV]["host"].blank?
      passed_file     = ENV['file']
      passed_filename = ENV['bootstrap'] == true ? 'bootstrap_data.sql' : ENV['file_name']
      sql_root        = File.join(RAILS_ROOT, 'db', 'bootstrap')
      ignore_tables   = ENV['ignore_tables'].split(',') if ENV['ignore_tables'].present?
      passed_params   = ENV['additional_params'].split(',') if ENV['additional_params'].present?

      if passed_file.blank?
        sql_filename  = passed_filename || "#{RAILS_ENV}_database_dump.sql"
        sql_path      = File.join(sql_root,sql_filename)
      else
        sql_filename  = File.basename(ENV['file'])
        sql_path      = ENV['file']
      end

      #mysqldump --help

      #Create directories if they don't exist
      Dir.mkdir sql_root if !File.exists?(sql_root)

      puts "Generating SQL Dump of Database - #{sql_path}"

      default_sql_attrs = "-q --add-drop-table --add-locks --extended-insert --lock-tables --single-transaction"
      if ignore_tables.present?
        ignore_tables.each do |table_name|
           default_sql_attrs += " --ignore-table=#{config[RAILS_ENV]["database"]}.#{table_name.strip}"
        end
      end

      if passed_params.present?
        passed_params.each do |param|
           default_sql_attrs += " #{param}"
        end
      end

      #--all-tablespaces
      if config[RAILS_ENV]["password"].blank?
        `mysqldump #{default_sql_attrs} -h #{config[RAILS_ENV]["host"]} -u #{config[RAILS_ENV]["username"]} #{config[RAILS_ENV]["database"]} > #{sql_path}`
      else
        `mysqldump #{default_sql_attrs} -h #{config[RAILS_ENV]["host"]} -u #{config[RAILS_ENV]["username"]} -p#{config[RAILS_ENV]["password"]} #{config[RAILS_ENV]["database"]} > #{sql_path}`
      end
      puts "SQL Dump completed --> #{sql_path}"
    else
      raise "Task not supported by '#{config[RAILS_ENV]['adapter']}'"
    end
  end

  desc "Loads the SQL dump into the current environment"
  task :database_load do
    load 'config/environment.rb' unless Object.const_defined?(:ActiveRecord)
    config = ActiveRecord::Base.configurations

      #Error checking
      raise "Please ensure your config/database.yml file has a host for the database. eg. host = localhost" if config[RAILS_ENV]["host"].blank?

      sql_filename = ENV['file'] || File.join('db', 'bootstrap','bootstrap_data.sql')

      puts "No file location passed. Loading bootstrap defaults..." if ENV['file'].blank?
      puts "Attempting to load data... #{sql_filename}"

      sql_path = File.join(RAILS_ROOT, sql_filename)

      raise "Unable to find SQL file to load at location - #{sql_path}" if !File.exists?(sql_path)

      case config[RAILS_ENV]["adapter"]
      when 'mysql'
        ActiveRecord::Base.establish_connection(config[RAILS_ENV])

        puts "Importing Database SQL..."
        if config[RAILS_ENV]["password"].blank?
          `mysql -f -h #{config[RAILS_ENV]["host"]} -u #{config[RAILS_ENV]["username"]} #{config[RAILS_ENV]["database"]} < #{sql_filename}`
        else
          `mysql -f -h #{config[RAILS_ENV]["host"]} -u #{config[RAILS_ENV]["username"]} -p"#{config[RAILS_ENV]["password"]}" #{config[RAILS_ENV]["database"]} < #{sql_filename}`
        end
        puts "Database load completed..."
      else
        raise "Task not supported by '#{config[RAILS_ENV]['adapter']}'"
      end
  end

  desc "Backup the mysql db to a set number of dump files"
  task :database_backup do
    load 'config/environment.rb' unless Object.const_defined?(:ActiveRecord)
    config = ActiveRecord::Base.configurations

      #Error checking
      raise "Please ensure your config/database.yml file has a host for the database. eg. host = localhost" if config[RAILS_ENV]["host"].blank?

      backup_numbers  = ENV['total_backups'].present? ? ENV['total_backups'].to_i : 5
      backup_location = ENV['backup_location'] || File.join(RAILS_ROOT, 'db', 'backup')

      #Create directories if they don't exist
      Dir.mkdir backup_location if !File.exists?(backup_location)

      puts "No 'total_backups' passed. Setting maximum backup files : #{backup_numbers}..." if ENV['total_backups'].blank?
      puts "No 'backup_location' passed. Saving to : #{backup_location}..." if ENV['backup_location'].blank?

      #Check for current releases
      Dir.chdir(backup_location) do
        #Delete records
        sorted_files = Dir.glob("*.sql").sort_by {|f| test(?M, f)}
        puts " -- Found #{sorted_files.size} backup files"
        if sorted_files.size >= backup_numbers
          puts "Cleaning up backups..."
          sorted_files.reverse.each_with_index do |file, i|
            if i >= (backup_numbers - 1)
              FileUtils.rm( file )
            end
          end
        end
      end

      sql_filename = "#{Time.now.strftime("%Y%m%d").to_s}_#{Time.now.strftime("%H%M%S")}.sql"
      puts "Attempting to dump data... #{sql_filename}"

      ENV['file'] = File.join(backup_location, sql_filename)
      Rake::Task['db:database_dump'].reenable
      Rake::Task['db:database_dump'].invoke


      puts "Backup complete."
  end

end
