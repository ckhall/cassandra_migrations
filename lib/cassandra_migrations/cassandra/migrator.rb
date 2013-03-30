# encoding: utf-8

module CassandraMigrations::Cassandra
  module Migrator
    
    def self.up_to_latest
      current_version = read_current_version
  
      new_migrations = get_all_migration_names.sort.select do |migration_name|
        get_version_from_migration_name(migration_name) > current_version
      end
        
      if !new_migrations.empty?
        new_migrations.each { |migration| up(migration) }
      end
      
      new_migrations.size
    end
  
    def self.rollback(count=1)
      current_version = read_current_version
      
      executed_migrations = get_all_migration_names.sort.reverse.select do |migration_name|
        get_version_from_migration_name(migration_name) <= current_version
      end
      
      down_count = 0
      
      if !executed_migrations.empty?
        count.times do |i|
          if executed_migrations[i]
            down(executed_migrations[i], executed_migrations[i])
            down_count += 1
          end
        end
      end
      
      down_count
    end
  
    def self.read_current_version
      CassandraMigrations::Cassandra.select("metadata", :selection => "data_name='version'", :projection => 'data_value').first['data_value'].to_i
    end
    
private
  
    def self.up(migration_name)
      # load migration
      require migration_name
      # run migration
      get_class_from_migration_name(migration_name).up
      
      # update version
      CassandraMigrations::Cassandra.write("metadata", {:data_name => 'version', :data_value => get_version_from_migration_name(migration_name).to_s})
    end
    
    def self.down(migration_name, previous_migration_name=nil)
      # load migration
      require migration_name
      # run migration
      get_class_from_migration_name(migration_name).down
      
      # downgrade version
      if previous_migration_name
        CassandraMigrations::Cassandra.write("metadata", {:data_name => 'version', :data_value => get_version_from_migration_name(previous_migration_name).to_s})
      else
        CassandraMigrations::Cassandra.write("metadata", {:data_name => 'version', :data_value => '0'})
      end
    end
    
    def self.get_all_migration_names
      Dir[Rails.root.join("db", "cassandra_migrate/[0-9]*_*.rb")]
    end
  
    def self.get_class_from_migration_name(filename)
      filename.match(/[0-9]{14}_(.+)\.rb$/).captures.first.camelize.constantize    
    end  
    
    def self.get_version_from_migration_name(migration_name)
      migration_name.match(/([0-9]{14})_.+\.rb$/).captures.first.to_i
    end
  end
end