
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

      rex = /\Aflorist_/
      rex = /\Aflor(ist)?_/ if opts[:flor]

      db.tables.each { |t|
        db[t].delete if rex.match(t.to_s) && db[t].columns.size > 2 }

      db.disconnect if db_or_db_uri.is_a?(String)

      nil
    end

    def migrate(db_or_db_uri, to=nil, from=nil, opts=nil)

      opts = [ to, from, opts ].find { |e| e.is_a?(Hash) } || {}
      opts[:target] ||= to if to.is_a?(Integer)
      opts[:current] ||= from if from.is_a?(Integer)

      opts[:table] = (opts[:migration_table] || :schema_info).to_sym
      opts[:column] = (opts[:migration_column] || :version).to_sym
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
      when Flor::Storage then o.db
      else o
      end
    end
  end
end

