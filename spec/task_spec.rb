
#
# specifying florist
#
# Sat Feb 23 07:03:08 JST 2019
#

require 'spec_helper'


describe '::Florist' do

  before :each do

    @unit = Flor::Unit.new(
      loader:
        Flor::HashLoader,
      db_migrations:
        'spec/migrations',
      sto_uri:
        RUBY_PLATFORM.match(/java/) ?
        'jdbc:sqlite://tmp/florist_test.db' :
        'sqlite::memory:')
    @unit.conf['unit'] = 'utspec'
    #@unit.hook('journal', Flor::Journal)
    @unit.storage.delete_tables
    @unit.storage.migrate(allow_missing_migration_files: true)
    @unit.start

    @db = @unit.storage.db
  end

  after :each do

    @unit.shutdown
  end

  describe '::Task' do

    describe '.tasks' do

      it 'creates a dedicated dataset' do

        @unit.add_tasker('accounting', Florist::GroupTasker)
        @unit.add_tasker('sales', Florist::GroupTasker)

        exids = []

        exids << @unit.launch(%q{ accounting _ }, wait: 'task')['exid']
        exids << @unit.launch(%q{ sales _ }, wait: 'task')['exid']

        wait_until { @db[:florist_tasks].count == 2 }

        tds = Florist.tasks(@db)

        expect(tds.count).to eq(2)
        expect(tds.all.collect(&:exid).sort).to eq(exids.sort)
      end
    end
  end

  describe '::Task999 (dedicated dataset)' do

    before :each do

      @unit.add_tasker('accounting', Florist::GroupTasker)
      @unit.add_tasker('sales', Florist::GroupTasker)

      2.times { @unit.launch(%q{ accounting _ }) }
      2.times { @unit.launch(%q{ sales _ }) }
      wait_until { @db[:florist_tasks].count == 4 }
    end

    describe '#by_resource(name)' do

      it 'returns the tasks assigned to the given resource' do

        tds = Florist.tasks(@db)

        ts = tds.by_resource('accounting')

        expect(ts.size).to eq(2)
      end
    end

    describe '#by_resource(type, name)' do

      it 'returns the tasks assigned to the given resource'
    end
  end
end

