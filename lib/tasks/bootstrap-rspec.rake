require File.dirname(__FILE__) + '/../bootstrap_helpers.rb'
include BootstrapHelpers
namespace :db do
  namespace :test do

    desc 'Use bootstrap_data.sql to build initial database for specs with migrations'
    task :custom_prepare => :environment do
      #To load sql dump with migrations for specs: edit rspec.rake and alter the spec_prereq variable
      #for example :
      #spec_prereq = File.exist?(File.join(RAILS_ROOT, 'config', 'database.yml')) ? "db:test:custom_prepare" : :noop
      Rails.env = 'test'
      ENV['file'] ||= File.join('db', 'bootstrap', 'bootstrap_data.sql')

      run_rake('db:test:clone_structure') if defined?(ActiveRecord)
      run_rake('db:database_load')
      run_rake('db:migrate')

    end

  end
end
