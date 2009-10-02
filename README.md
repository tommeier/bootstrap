# Bootstrap

## Purpose

Collection of useful rake tasks to make seeding, extracting, maintaining, backup and testing a database with migrations more easier.
  
## Install

  	script/plugin install git://github.com/tommeier/bootstrap.git bootstrap

## Commands (Example Usage)

### Bootstrap - Fixture Load
		rake db:bootstrap:load 

Load a set of CSV's or YML's from "#{RAILS\_ROOT}/db/bootstrap", or pass it parameter "FIXTURES=" for a specific set of files to load into the database. Best used for initial loading of the database with data usually required at the start of your projects, such as default users. YML / CSV fixture files can be numbered to ensure the correct ordering of related files eg: 001\_users.yml, 002\_roles.yml.

### Bootstrap - Database Dump / Load
		rake db:database_dump 
		rake db:database_dump RAILS_ENV=production							#Dump specific environment using database.yml  
		rake db:database_dump file=db/bootstrap/live_database_dump.sql		#Dump to specified location
		rake db:database_dump file_name=live_database_dump.sql				#Dump file to default bootstrap location
		rake db:database_dump bootstrap=true								#Dump default bootstrap file (for use in specs and initial clean DB load - db/bootstrap/bootstrap_data.sql)

Create a mysql database dump of the environment in a specified or default location for loading later (or just as a backup file). This will overwrite any file by the same name, so if used for backup specify a unique filename. 

		rake db:database_load												#Load default bootstrap file ( db/bootstrap/bootstrap\_data.sql)
		rake db:database_load file=db/bootstrap/live_database_dump.sql		#Load the sql dump file specified  

Load, and overwrite, current database environment with a passed file name.

### Bootstrap - Reset Application
		rake db:reset_app 													#Reset the application to bootstrap data dump
		rake db:reset_app file=db/bootstrap/live_database_dump.sql      	#Reset the application to specified database dump

For a clean start to your app, or a move back to a specified snapshot and then to have migrations run upon the data. Very useful for testing migrations on a production database snapshot. This process will:

 * Drop current database tables for current environment
 * Create all tables
 * Load default bootstrap database file or specified file in 'file' parameter 
 * Apply migrations from the point of the database snapshot

### Bootstrap - RSPEC Integration
		
To enable specs to be loaded from an SQL dump, with migrations, edit your rspec.rake file and alter the spec\_prereq variable to run the following rake command: db:test:custom\_prepare (instead of db:test:prepare). With this you can run with a default data set, or your complete data set for thorough testing purposes simply by running : rake spec.
You can also load a different 'custom' spec database by running with the file parameter.
eg. rake spec file=db/bootstrap/my_spec_fixtures.sql

### Bootstrap - Data Extractors (BETA)
		rake db:extract_data_migrations
		rake db:extract_data_migrations table=users
		
Extract existing data from all database tables or a specified table into a generated migration file. Can be useful for having effective rollback statements when deleting records. Generated migrations are saved into : "#{RAILS\_ROOT}/tmp/generated\_migrations".

		rake db:extract_fixtures

Current contents of the database is extracted into numbered yml files, able to be processed by "rake db:bootstrap:load" command. YML files are saved : "#{RAILS\_ROOT}/tmp/generated\_ymls" and will need to be moved to default bootstrap directory when satisifed with ordering.
		
## Requirements

 * database.yml has a 'host' value set for environments
 * mysql - for database dump/load

Copyright (c) 2009 Tom Meier, released under the MIT license
