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
      Rake::Task['db:drop'].invoke 

      puts "Creating database tables...\n"
      Rake::Task['db:create'].invoke
      
      puts "Loading database dump...\n"
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
      
      default_sql_attrs = "-q --add-drop-table --add-locks --extended-insert --lock-tables"
      File.open(sql_path, "w+") do |f|
        if config[RAILS_ENV]["password"].blank?
          f << `mysqldump #{default_sql_attrs} -h #{config[RAILS_ENV]["host"]} -u #{config[RAILS_ENV]["username"]} #{config[RAILS_ENV]["database"]}`
        else
          f << `mysqldump #{default_sql_attrs} -h #{config[RAILS_ENV]["host"]} -u #{config[RAILS_ENV]["username"]} -p#{config[RAILS_ENV]["password"]} #{config[RAILS_ENV]["database"]}`
        end
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
    
end
