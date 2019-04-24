
module Florist

  VERSION = '0.16.0'
end

require 'flor'
require 'flor/unit'

require 'florist/errors'

require 'florist/task'

require 'florist/taskers'
require 'florist/list'


module Florist

  class << self

    def migration_dir

      File.join(__dir__, 'florist/migrations')
    end

    def delete_tables(db_or_db_uri, opts={})

      db =
        db_or_db_uri.is_a?(String) ?
        Sequel.connect(db_or_db_uri, opts) :
        db_or_db_uri

      db.tables.each { |t| db[t].delete if t.to_s.match(/^florist_/) }

      db.disconnect if db_or_db_uri.is_a?(String)

      nil
    end

    def migrate(db_or_db_uri, to=nil, from=nil, opts=nil)

      opts = [ to, from, opts ].find { |e| e.is_a?(Hash) } || {}
      opts[:target] ||= to if to.is_a?(Integer)
      opts[:current] ||= from if from.is_a?(Integer)
        #
        # defaults for the migration version table:
        # { table: :schema_info,
        #   column: :version }

      skip = opts[:sparse_migrations]
      if skip && ! opts.has_key?(:allow_missing_migration_files)
        opts[:allow_missing_migration_files] = true
      end

      dir =
        opts[:migrations] ||
        opts[:migration_dir] ||
        Florist.migration_dir

      db =
        db_or_db_uri.is_a?(String) ?
        Sequel.connect(db_or_db_uri, opts) :
        db_or_db_uri

      Sequel::Migrator.run(db, dir, opts)

      db.disconnect if db_or_db_uri.is_a?(String)

      nil
    end
  end
end

