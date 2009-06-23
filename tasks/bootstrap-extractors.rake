namespace :db do
  #Create data migration files from the data present in each table as generating data migrations is painful
  desc 'Generate data migration files from data in the existing environments database.'
    task :extract_data_migrations => :environment do
      default_migration_generation_path = "#{RAILS_ROOT}/tmp/generated_migrations"
      Dir.mkdir (default_migration_generation_path) if !File.exists?(default_migration_generation_path)
      
      puts "===================================================\n"
      puts "==         Rake - db:extract_data_migrations     ==\n"
      puts "===================================================\n"
      puts "* Default folder for data migration file export : '#{default_migration_generation_path}'"
      puts "* usage : 'rake db:extract_data_migrations'\n\n"
      puts "* usage : 'rake db:extract_data_migrations table=users'\n\n"
      
      
      sql  = "SELECT * FROM %s"
      
      if ENV["table"]
        extract_tables = [ENV["table"]]
      else
        extract_tables = ActiveRecord::Base.connection.tables
      end 
      
      skip_tables = ["schema_info", "sessions", "schema_migrations"]
      file_counter = '000'
      
      initial_indent = (" " * 4)
      ActiveRecord::Base.establish_connection
      (extract_tables - skip_tables).each do |table_name|
        
        file_prefix = "data_migration_export_"
        
        data = ActiveRecord::Base.connection.select_all(sql % table_name)

        next if data.empty?
        puts "Creating Data Migration File for - " + table_name
        
        #TODO : Clean it up and generate real hashes for cleaner use and display        
        File.open(File.join(default_migration_generation_path, "#{file_prefix + file_counter.succ! + '_' + table_name}.rb"), 'w') do |file|
          
          #Fill array of conditions from database
          conditions_array = []
          data.each do |record|
            record_attributes = []
            record.each do |key, value|
              current_attr_hash = ":#{key} => '#{value}',"
              next if !value || key.strip.downcase == 'id' || key.strip.downcase == 'updated_at' || key.strip.downcase == 'created_at'              
              record_attributes << current_attr_hash unless current_attr_hash.blank?
            end
            record_attributes.last.chop! #strip final comma and final return
            conditions_array << record_attributes# if record_conditions.size > 0
          end

          file.puts "class CreateDataMigrationFor#{table_name.classify} < ActiveRecord::Migration"
          file.puts "  def self.up"
                    
          #Generate Creates
          conditions_array.each do |conditions|
            #TODO : Find any object with an _id in the title and create a variable to be used in create statements as the object
            str_var_name = "#{table_name.classify}.create!("
            
            file.puts " "
            create_start = "#{initial_indent}#{str_var_name}"
            create_spacer = (" " * create_start.chars.size)
            
            file.puts create_start
            conditions.each do |condition|
              file.puts initial_indent + create_spacer + "#{condition.strip.to_s}"
            end
            file.puts create_spacer + ")\n"
          end
          
          file.puts "  end"
          file.puts "\n"
          file.puts "  def self.down"
          
          counter = 0
          #Create Drops
          conditions_array.each do |conditions|
            #TODO : Always set conditions to full field name : ie: = role_id NOT just role
            #TODO : Check if it is a join table, if no id exists a full SQL delete statement should be written
            counter += 1
            str_var_name = "#{table_name.tableize}_#{counter}"
            
            condition_start = "#{initial_indent}#{str_var_name} = #{table_name.classify}.find(:first, :conditions => {"
            condition_spacer = (" " * condition_start.chars.size)
            file.puts condition_start
            conditions.each do |condition|
              file.puts initial_indent + condition_spacer + "#{condition.strip.to_s}"
            end
            file.puts condition_spacer + "})"
            file.puts "#{initial_indent}#{table_name.classify}.delete(#{str_var_name}) if #{str_var_name}\n"
          end
          
          file.puts "  end"
          file.puts "end"          

        end

    end
  end

  # Creating YAML files for sample data can be painful.This task extracts them from the
  # db into the tmp directory
  desc 'Create YAML fixtures from data in an existing database.'
   task :extract_fixtures => :environment do
    default_yml_generation_path = "#{RAILS_ROOT}/tmp/generated_ymls"
    Dir.mkdir (default_yml_generation_path) if !File.exists?(default_yml_generation_path)
     
    puts "Please remember to prefix ymls with numbers before integrating with the bootstrap folder where required."
    puts "YMLs are being generated in : #{default_yml_generation_path}"
    sql  = "SELECT * FROM %s"
    skip_tables = ["schema_info", "sessions"]

    ActiveRecord::Base.establish_connection
    (ActiveRecord::Base.connection.tables - skip_tables).each do |table_name|
      i = "000"
      
      data = ActiveRecord::Base.connection.select_all(sql % table_name)
      
      next if data.empty?
      puts "Creating YML for - " + table_name

      File.open(File.join(default_csv_generation_path, "#{table_name}.yml"), 'w') do |file|
        file.write data.inject({}) { |hash, record|
         
          record['updated_at'] = '<%= Time.now.utc.to_s(:db) %>' if record['updated_at']
          record['created_at'] = '<%= Time.now.utc.to_s(:db) %>' if record['created_at']
          hash["#{table_name}_#{i.succ!}"] = record
          hash
        }.to_ordered_yaml #Ordered yml new method located in initializers/ordered_yml.rb
      end
    end


  end  

  
  
end
