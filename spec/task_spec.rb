
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

    @worklist = Florist::Worklist.new(@unit)
  end

  after :each do

    @unit.shutdown
  end

  describe '::Task' do

    context 'accessors' do

      before :each do

        @unit.add_tasker(
          'alice',
          class: Florist::WorklistTasker,
          include_vars: true)

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

      describe '#tasker' do

        it 'returns the tasker as indicated in the execution' do

          t = @worklist.tasks.first

          expect(t.tasker).to eq('alice')
        end
      end

      describe '#taskname / #task_name' do

        it 'returns the name of the task' do

          t = @worklist.tasks.first

          expect(t.taskname).to eq('send message')
          expect(t.task_name).to eq('send message')
        end
      end

      describe '#attls1' do

        it 'returns the second string attribute in the attl' do

          t = @worklist.tasks.first

          expect(t.attls1).to eq('send message')
        end
      end

      describe '#message' do

        it 'returns the original message' do

          t = @worklist.tasks.first
          m = t.message

          expect(m['m']).to eq(@r['m'])
          expect(m['point']).to eq('task')
          expect(m['tasker']).to eq('alice')
        end
      end

      describe '#attl / #atts / #atta' do

        it 'returns the task attribute list/array' do

          t = @worklist.tasks.first

          expect(t.attl).to eq([ 'alice', 'send message' ])
          expect(t.atts).to eq([ 'alice', 'send message' ])
          expect(t.atta).to eq([ 'alice', 'send message' ])
        end
      end

      describe '#attd / #atth' do

        it 'returns the task attribute dictionary' do

          t = @worklist.tasks.first

          expect(t.attd).to eq({ 'addressee' => 'bob' })
          expect(t.atth).to eq({ 'addressee' => 'bob' })
        end
      end

      describe '#vars / #vard' do

        it 'returns the var dictionary coming with the task' do

          t = @worklist.tasks.first

          expect(t.vars).to eq({ 'v0' => 'hello', 'v1' => 2345 })
          expect(t.vard).to eq({ 'v0' => 'hello', 'v1' => 2345 })
        end
      end

      describe '#execution' do

        it 'returns nil if the task db is separate from the execution db' do

          @unit.storage.db.drop_table(:flor_executions)

          t = @worklist.tasks.first

          expect(t.execution).to eq(nil)
        end

        it 'returns the execution that emitted the task' do

          t = @worklist.tasks.first

          x = t.execution

          expect(x.exid).to eq(t.exid)

          expect(
            x.data['nodes']['0_2']['payload']
          ).to eq(
            { 'kilroy' => 'was here', 'ret' => nil }
          )
        end
      end

      describe '#worklist' do

        it 'returns the worklist from which the task was fetched' do

          t = @worklist.tasks.first

          expect(t.class.worklist).to eq(@worklist)
          expect(t.worklist).to eq(@worklist)
        end
      end

      describe '#payload / #fields' do

        it 'returns the current payload' do

          t = @worklist.tasks.first

          expect(t.payload).to eq({ 'kilroy' => 'was here', 'ret' => nil })
          expect(t.payload).to eq(@r['payload'])
          expect(t.fields).to eq(@r['payload'])
        end

        it 'returns the latest payload' do

          t = @worklist.tasks.first

          c = t.push_payload(:kilroy => 'was there')

          expect(c.size).to eq(1)
          expect(c.first.keys).to eq(%w[ tstamp payload ])

          t = @worklist.tasks.first

          expect(t.payload).to eq({ 'kilroy' => 'was there' })
        end
      end
    end

    context 'graph' do

      before :each do

        @unit.add_tasker(
          'alice',
          Florist::WorklistTasker)

        @r = @unit.launch(
          %q{
            alice 'send message'
          },
          wait: 'task')

        wait_until { @worklist.tasks.count == 1 }
      end

      describe '#transition, #last_transition' do

        it 'returns the last transition seen by the task' do

          t = @worklist.task_table.first

          s = t.transition

          expect(s.class.ancestors).to include(Florist::Transition)
          expect(s.task_id).to eq(t.id)
          expect(s.state).to eq('created')
        end

        it 'returns the last transition seen by the task (post allocation)' do

          t = @worklist.task_table.first

          t.offer('user', 'bob')

          #t = @worklist.task_table.first
          t.refresh

          s = t.transition
          a = s.assignment

          expect(s.state).to eq('offered')
          expect(a.resource_type).to eq('user')
          expect(a.resource_name).to eq('bob')
        end
      end

      describe '#transitions' do

        it 'returns all the transitions seen by the task' do

          t = @worklist.task_table.first

          t.allocate('role', 'rm')

          t.refresh

          t.allocate('user', 'bob')

          ss = t.transitions

          expect(ss.collect(&:state)).to eq(%w[ created allocated ])
#pp ss.collect { |s| s.assignments.collect(&:to_h) }
        end
      end

      describe '#assignments, #current_assignments' do

        it 'returns the current assignments for the task'
      end
    end

    context 'actions' do

      # TODO reintroduce, but with the worklist (session) concept
    end
  end
end

