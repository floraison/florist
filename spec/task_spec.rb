
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
      sto_migration_table: :flor_schema_info)
    @unit.conf['unit'] = 'tskspec'
    #@unit.hook('journal', Flor::Journal)
    @unit.storage.delete_tables
    @unit.storage.migrate
    @unit.start

    Florist.delete_tables(storage_uri)
    Florist.migrate(storage_uri, table: :florist_schema_info)

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

      describe '#taskname / #task_name / #name' do

        it 'returns the name of the task' do

          t = @worklist.tasks.first

          expect(t.taskname).to eq('send message')
          expect(t.task_name).to eq('send message')
          expect(t.name).to eq('send message')
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
    end

    context 'misc' do

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

      describe '#to_h' do

        it 'returns a JSON-friendly representation' do

          t = @worklist.tasks.first
          t.allocate('user', 'zed')
          t.refresh

          h = t.to_h

          expect(h[:id]).to eq(t.id)
          expect(h[:state]).to eq('allocated')
          expect(h[:status]).to eq('active')
          expect(h[:transitions].count).to eq(2)
          expect(h[:assignments].count).to eq(1)
          expect(h[:last_transition_id]).to eq(h[:transitions].last[:id])
        end
      end
    end

    context 'environment accessors' do

      before :each do

        @unit.add_tasker('eve', Florist::WorklistTasker)

        @unit.launch(%q{ eve 'prepare ground' })

        wait_until { @worklist.tasks.count == 1 }
      end

      describe '#execution' do

        after :each do

          @unit.storage.db.tables.each { |t| @unit.storage.db.drop_table(t) }
        end

        it 'returns nil if the task db is separate from the execution db' do

          @unit.storage.db.drop_table(:flor_executions)

          t = @worklist.tasks.first

          expect(t.execution).to eq(nil)
        end

        it 'returns the execution that emitted the task' do

          t = @worklist.tasks.first

          x = wait_until { t.execution }

          expect(x.exid).to eq(t.exid)

          expect(
            x.data['nodes']['0']['task']
          ).to eq(
            { 'tasker' => 'eve', 'name' => 'prepare ground' }
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
    end

    context 'graph' do

      before :each do

        @unit.add_tasker(
          'alice',
          Florist::WorklistTasker)

        @unit.launch(
          %q{
            alice 'send message'
          },
          payload: { 'text' => 'lore ipsum' })

        wait_until { @worklist.tasks.count == 1 }
      end

      describe '#transition, #last_transition' do

        it 'returns the last transition seen by the task' do

          t = @worklist.tasks.first

          s = t.transition

          expect(s.class.ancestors).to include(Florist::Transition)
          expect(s.task_id).to eq(t.id)
          expect(s.name).to eq('create')
          expect(s.state).to eq('created')
        end

        it 'returns the last transition seen by the task (post allocation)' do

          t = @worklist.tasks.first

          t.offer('user', 'bob')

          #t = @worklist.tasks.first
          t.refresh

          s = t.transition
          a = s.assignment

          expect(s.name).to eq('offer')
          expect(s.state).to eq('offered')
          expect(a.resource_type).to eq('user')
          expect(a.resource_name).to eq('bob')
        end
      end

      describe '#transitions' do

        it 'returns all the transitions seen by the task' do

          t = @worklist.tasks.first

          t.allocate('role', 'rm')

          t.refresh

          t.allocate('user', 'bob')

          ss = t.transitions

          expect(ss.collect(&:name)).to eq(%w[ create allocate ])
          expect(ss.collect(&:state)).to eq(%w[ created allocated ])
        end
      end

      describe '#payload / #fields' do

        it 'returns the current payload' do

          t = @worklist.tasks.first

          expect(t.payload
            ).to eq('text' => 'lore ipsum', 'ret' => 'send message')
          expect(t.fields
            ).to eq('text' => 'lore ipsum', 'ret' => 'send message')
        end

        it 'returns the latest payload' do

          t = @worklist.tasks.first
          t.offer('user', 'bob', payload: { colour: 'blue' }, r:true)

          expect(t.fields).to eq('colour' => 'blue')
        end
      end

      describe '#tname' do

        it 'returns the current name (transition.name)' do

          t = @worklist.tasks.first

          expect(t.tname).to eq('create')
        end
      end

      describe '#state' do

        it 'returns the current state (transition.state)' do

          t = @worklist.tasks.first

          expect(t.state).to eq('created')
        end
      end

      describe '#assignment' do

        it 'returns nil if there are no assignments' do

          t = @worklist.tasks.first

          expect(t.assignment).to eq(nil)
        end

        it 'returns the first current assignment' do

          t = @worklist.tasks.first

          t.offer('user', 'warwick')
          t.refresh
          t.offer('user', 'percy')
          t.refresh

          a = t.assignment

          expect(a.rtype).to eq('user')
          expect(a.rname).to eq('warwick')
        end
      end

      describe '#assignments, #current_assignments' do

        it 'returns [] if none' do

          t = @worklist.tasks.first

          expect(t.assignments).to eq([])
        end

        it 'returns the current assignments' do

          t = @worklist.tasks.first

          t.offer('user', 'giraud')
          t.refresh
          t.allocate('user', 'warwick')
          t.refresh
          t.allocate('user', 'percy')
          t.refresh

          as = t.assignments

          expect(as.size).to eq(2)

          expect(as[0].rtype).to eq('user')
          expect(as[0].rname).to eq('warwick')
          expect(as[1].rtype).to eq('user')
          expect(as[1].rname).to eq('percy')

          expect(t.transitions.size
            ).to eq(3)
          expect(t.transitions.collect(&:state)
            ).to eq(%w[ created offered allocated ])

          expect(t.last_transition.state).to eq('allocated')
        end
      end

      describe '#all_assignments' do

        it 'returns all the assignments, whatever the transition' do

          t = @worklist.tasks.first

          sid0 = t.last_transition.id

          sid1 = t.offer('user', 'warwick')
          t.refresh
          sid1b = t.offer('user', 'percy')
          t.refresh
          sid2 = t.allocate('user', 'fluellen')
          t.refresh

          expect(sid1b).to eq(sid1)

          expect(t.all_assignments.collect { |a| a.task.id }
            ).to eq([ t.id, t.id, t.id ])
          expect(t.all_assignments.collect { |a| a.last_transition.id }
            ).to eq([ sid1, sid1, sid2 ])
          expect(t.all_assignments.collect { |a| a.transitions.collect(&:id) }
            ).to eq([ [ sid1 ], [ sid1 ], [ sid2 ] ])
        end
      end
    end
  end
end

