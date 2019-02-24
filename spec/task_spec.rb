
#
# specifying florist
#
# Sat Feb 23 07:03:08 JST 2019
#

require 'spec_helper'


describe '::Florist' do

  before :each do

    @unit = Flor::Unit.new(
      loader: Flor::HashLoader,
      sto_uri: storage_uri,
      sto_migration_dir: 'spec/migrations',
      sto_sparse_migrations: true)
    @unit.conf['unit'] = 'tskspec'
    #@unit.hook('journal', Flor::Journal)
    @unit.storage.delete_tables
    @unit.storage.migrate
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

    context 'accessors' do

      before :each do

        @unit.add_tasker(
          'alice',
          { class: Florist::UserTasker, include_vars: true })

        @r = @unit.launch(
          %q{
            sequence
              set v0 'hello'
              set v1 2345
              alice 'send message' addressee: 'bob'
          },
          payload: { 'kilroy' => 'was here' },
          wait: 'task')

        wait_until { @unit.executions.count == 1 }
      end

      describe '#message' do

        it 'returns the original message' do

          t = @unit.tasks.first
          m = t.message

          expect(m['m']).to eq(@r['m'])
          expect(m['point']).to eq('task')
          expect(m['tasker']).to eq('alice')
        end
      end

      describe '#payload / #fields' do

        it 'returns the current payload' do

          t = @unit.tasks.first

          expect(t.payload).to eq({ 'kilroy' => 'was here', 'ret' => nil })
          expect(t.payload).to eq(@r['payload'])
          expect(t.fields).to eq(@r['payload'])
        end
      end

      describe '#assignments' do

        it 'lists the task assignments' do

          t = @unit.tasks.first

          expect(t.assignments.size).to eq(1)

          a = t.assignments.first

          expect(a.task_id).to eq(t.id)
          expect(a.task.id).to eq(t.id)
        end
      end

      describe '#attl / #atts / #atta' do

        it 'returns the task attribute list/array' do

          t = @unit.tasks.first

          expect(t.attl).to eq([ 'alice', 'send message' ])
          expect(t.atts).to eq([ 'alice', 'send message' ])
          expect(t.atta).to eq([ 'alice', 'send message' ])
        end
      end

      describe '#attd / #atth' do

        it 'returns the task attribute dictionary' do

          t = @unit.tasks.first

          expect(t.attd).to eq({ 'addressee' => 'bob' })
          expect(t.atth).to eq({ 'addressee' => 'bob' })
        end
      end

      describe '#tasker' do

        it 'returns the tasker as indicated in the execution' do

          t = @unit.tasks.first

          expect(t.tasker).to eq('alice')
        end
      end

      describe '#taskname / #task_name' do

        it 'returns the name of the task' do

          t = @unit.tasks.first

          expect(t.taskname).to eq('send message')
          expect(t.task_name).to eq('send message')
        end
      end

      describe '#vars / #vard' do

        it 'returns the var dictionary coming with the task' do

          t = @unit.tasks.first

          expect(t.vars).to eq({ 'v0' => 'hello', 'v1' => 2345 })
          expect(t.vard).to eq({ 'v0' => 'hello', 'v1' => 2345 })
        end
      end

      describe '#execution' do

        it 'returns nil if the task db is separate from the execution db' do

          @unit.storage.db.drop_table(:flor_executions)

          t = @unit.tasks.first

          expect(t.execution).to eq(nil)
        end

        it 'returns the execution that emitted the task' do

          t = @unit.tasks.first

          x = t.execution

          expect(x.exid).to eq(t.exid)

          expect(
            x.data['nodes']['0_2']['payload']
          ).to eq(
            { 'kilroy' => 'was here', 'ret' => nil }
          )
        end
      end
    end

    context 'actions' do

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

          expect(@unit.tasks.count).to eq(0)
          expect(@unit.task_assignments.count).to eq(0)
        end
      end

      describe '#return_error' do

        it 'returns an error instead of the task'
      end

      describe '#reassign' do

        it 'removes the current assignments and inserts new ones'
      end

      describe '#assign' do

        it 'adds news assignments for a task'
      end

      describe '#unassign' do

        it 'deletes all the assignments for the task'
      end
    end
  end

  describe '::Task333 (dedicated dataset)' do

    before :each do

      @unit.add_tasker('accounting', Florist::GroupTasker)
      @unit.add_tasker('sales', Florist::GroupTasker)
      @unit.add_tasker('alice', Florist::UserTasker)

      2.times do
        @unit.launch(%q{ accounting _ })
        @unit.launch(%q{ sales _ })
        @unit.launch(%q{ alice _ })
      end

      wait_until { @db[:florist_tasks].count == 6 }

      @tasks = Florist.tasks(@db)
    end

    describe '#by_resource(name)' do

      it 'returns the tasks assigned to the given resource' do

        ts = @tasks.by_resource('accounting')

        expect(ts.size).to eq(2)
      end
    end

    describe '#by_resource(type, name)' do

      it 'returns the tasks assigned to the given resource' do

        ts = @tasks.by_resource('group', 'accounting')

        expect(ts.size).to eq(2)
      end
    end

    describe '#assigned_to' do

      it 'is an alias to #by_resource' do

        ts = @tasks.assigned_to('group', 'accounting')

        expect(
          ts.collect { |t| t.assignment.resource_type }
        ).to eq(%w[ group ] * 2)
        expect(
          ts.collect { |t| t.assignment.resource_name }
        ).to eq(%w[ accounting ] * 2)
      end
    end

    describe '#by_assignment' do

      it 'is an alias to #by_resource' do

        ts = @tasks.by_assignment('group', 'accounting')

        expect(
          ts.collect { |t| t.assignment.resource_type }
        ).to eq(%w[ group ] * 2)
        expect(
          ts.collect { |t| t.assignment.resource_name }
        ).to eq(%w[ accounting ] * 2)
      end
    end

    describe '#without_assignment' do

      it 'lists the tasks missing and assignments'
      it 'returns an empty array when all the task are assigned'
      it 'returns an empty array when there are no tasks'
    end
  end

  describe '::TaskAssignment999 (dedicated dataset)' do

    describe '#orphans' do

      it 'lists the assignments pointing to unknown tasks'
    end
  end
end

