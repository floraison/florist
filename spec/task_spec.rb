
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

    describe '#message' do

      it 'returns the original message' do

        @unit.add_tasker('accounting', Florist::GroupTasker)

        r = @unit.launch(%q{ accounting _ }, wait: 'task')

        t = @unit.tasks.first
        m = t.message

        expect(m['m']).to eq(r['m'])
        expect(m['point']).to eq('task')
        expect(m['tasker']).to eq('accounting')
      end
    end

    describe '#payload' do

      it 'returns the current payload' do

        @unit.add_tasker('accounting', Florist::GroupTasker)

        r = @unit.launch(%q{ accounting _ }, wait: 'task')

        t = @unit.tasks.first
        pl = t.payload

        expect(pl).to eq(r['payload'])
      end
    end

    describe '#assignments' do

      it 'lists the task assignments' do

        @unit.add_tasker('accounting', Florist::GroupTasker)

        @unit.launch(%q{ accounting _ }, wait: 'task')

        t = @unit.tasks.first

        expect(t.assignments.size).to eq(1)

        a = t.assignments.first

        expect(a.task_id).to eq(t.id)
        expect(a.task.id).to eq(t.id)
      end
    end

    describe '#return' do

      it 'returns a task to its execution' do

        @unit.add_tasker('alice', Florist::UserTasker)

        r = @unit.launch(%q{ alice _ }, wait: 'task')

        t = @unit.tasks.first

        t.payload['ret'] = 1234
        t.payload['name'] = 'Alice'
        t.return

        r = @unit.wait(r['exid'], 'terminated')

        expect(r['point']).to eq('terminated')
        expect(r['payload']['ret']).to eq(1234)
        expect(r['payload']['name']).to eq('Alice')
      end
    end

    describe '#return_error' do

      it 'returns an error instead of the task'
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

