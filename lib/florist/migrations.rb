
module Florist

  class << self

    def migration_dir

      File.join(__dir__, 'migrations')
    end

    # Delete tables in the storage database that begin with "florist_"
    # and have more than 2 columns (the Sequel schema_info table has 1 column
    # as of this writing)
    #
    def delete_tables(db_or_db_uri, opts={})

      db = connect(db_or_db_uri, opts)

      db.tables.each { |t|
        db[t].delete \
          if t.to_s.match(/^florist_/) && db[t].columns.size > 2 }

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

      db = connect(db_or_db_uri, opts)

      Sequel::Migrator.run(db, dir, opts)

      db.disconnect if db_or_db_uri.is_a?(String)

      nil
    end

    protected

    def connect(o, opts)

      case o
      when String then Sequel.connect(o, opts)
      else o
      end
    end
  end
end

