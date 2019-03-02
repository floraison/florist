
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

    context 'accessors' do

      before :each do

        @unit.add_tasker(
          'alice',
          { class: Florist::WorklistTasker, include_vars: true })

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

      describe '#attls1' do

        it 'returns the second string attribute in the attl' do

          t = @unit.tasks.first

          expect(t.attls1).to eq('send message')
        end
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

    context 'graph' do

      describe '#transition, #last_transition' do

        it 'returns the last transition seen by the task'
      end

      describe '#transitions' do

        it 'returns all the transitions seen by the task'
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

