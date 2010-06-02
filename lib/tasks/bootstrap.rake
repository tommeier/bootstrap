namespace :db do
  desc "Loads a schema.rb file into the database and then loads the initial database fixtures."
  task :bootstrap do |task_args|
    mkdir_p File.join(RAILS_ROOT, 'log')
    
    %w(environment db:migrate db:bootstrap:load tmp:create).each { |t| Rake::Task[t].execute task_args}
 
  end  
  
  namespace :bootstrap do
    desc "Load initial database fixtures (in db/bootstrap/*.yml) into the current environment's database.  Load specific fixtures using FIXTURES=x,y"
    
    task :load => :environment do
      require 'active_record/fixtures'
      puts "Additional Parameters - FIXTURES=x,y - Specific files to load"
      puts "Additional Parameters - RESET=true/false - Delete all content in the table before loading fixtures"
      start = Time.now
      
      bootstrap_location = File.join(RAILS_ROOT, 'db', 'bootstrap')

      if ENV['FIXTURES']
        fixture_files = ENV['FIXTURES'].split(/\s*,\s*/).map {|file| [File.join(bootstrap_location, file), file]}
      else
        found_files = Dir.glob(File.join(bootstrap_location, '*.{yml,csv}'))
        numbered_files = found_files.select {|path| path =~ /\d+_[^.]+\.yml\Z/i }
        fixture_files = numbered_files.sort {|x,y| x[/(\d+)_.*\Z/,1].to_i <=> y[/(\d+)_.*\Z/,1].to_i }.
          map {|fixture_path| [fixture_path[/(.*)\.(yml|csv)\Z/i,1], fixture_path[/\d+_([^.]+)\.(yml|csv)\Z/i, 1]] }
        fixture_files += (found_files - numbered_files).map {|file| path = file[0, file.rindex('.')]; [path, File.basename(path)]}
        raise "No fixtures found matching \"db/bootstrap/*.{yml,csv}\"! Specify fixtures using \"FIXTURES=\"" if fixture_files.empty?
      end

      fixture_counter = 0

      ActiveRecord::Base.establish_connection(RAILS_ENV.to_sym)
      #Disable foreign key constraints in import
      ActiveRecord::Base.connection.update "SET FOREIGN_KEY_CHECKS = 0"

      connection = ActiveRecord::Base.connection
      connection.transaction do
        
        fixtures = fixture_files.map do |fixture_path, table_name|
          fixture = Fixtures.new(connection, table_name, nil, fixture_path)
          fixture_counter += 1
          puts "#{fixture_counter}. Importing - " + table_name.titleize
          if ENV['RESET'] && ENV['RESET'].downcase == 'true'
            #Remove any existing data
            #TODO : This has to be removed when using multiple tables of the same type
            #Should only be run on first instance of the table... Perhaps check array of values for reset tables
            table_name.classify.constantize.delete_all
            fixture.delete_existing_fixtures
          end
          fixture.insert_fixtures
        end
      
        # Cap primary key sequences to max(pk).
        if connection.respond_to?(:reset_pk_sequence!)
          table_names.each do |table_name|
            connection.reset_pk_sequence!(table_name)
          end
        end
      end #connection.transaction(Thread.current['open_transactions'].to_i == 0) do
      
      #Re-enable foreign key constraints
      ActiveRecord::Base.connection.update "SET FOREIGN_KEY_CHECKS = 1"
      
      

      puts "*** #{fixture_counter} fixtures loaded..."
      puts "***-- from the '#{ENV['DATASET']}' dataset..." if ENV['DATASET']
      puts "Took " + (Time.now - start).seconds.to_s + " seconds to complete..."
      
    end #task :load => :environment do
  end #namespace :bootstrap do
  
   
  
end