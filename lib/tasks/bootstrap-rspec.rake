namespace :db do
  namespace :test do
        
    desc 'Use bootstrap_data.sql to build initial database for specs with migrations'
    task :custom_prepare => :environment do
      #To load sql dump with migrations for specs: edit rspec.rake and alter the spec_prereq variable
      #for example : 
      #spec_prereq = File.exist?(File.join(RAILS_ROOT, 'config', 'database.yml')) ? "db:test:custom_prepare" : :noop
      RAILS_ENV = 'test'
      ENV['file'] ||= File.join('db', 'bootstrap', 'bootstrap_data.sql')
      Rake::Task['db:database_load'].invoke
      Rake::Task['db:migrate'].invoke
    end
   
  end
end
