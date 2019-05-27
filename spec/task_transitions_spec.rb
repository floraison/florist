
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

    @worklist = Florist::Worklist.new(
      @unit,
      rtype: 'user', rname: 'waldo')
  end

  after :each do

    @unit.shutdown
  end

  describe '::Task' do

    context 'basic transitions' do

      before :each do

        @unit.add_tasker(
          'bob',
          Florist::WorklistTasker)

        @r = @unit.launch(
          %q{
            bob 'send message'
          },
          domain: 'org.acme',
          wait: 'task')

        wait_until { @worklist.task_ds.count == 1 }
      end

      it 'fails if the task changed meanwhile' do

        ta = @worklist.tasks.first
        tb = @worklist.tasks.first

        ta.allocate('user', 'charly')
        ta.refresh

        expect {
          tb.allocate('user', 'david')
        }.to raise_error(
          Florist::ConflictError, 'task outdated, update failed'
        )
      end

      describe 'a transition to the same state' do

        it 'reuses the current transition' do

          t = @worklist.tasks.first

          sid0 = t.allocate('user', 'charly')
          t.refresh
          sid1 = t.allocate('user', 'bob')
          t.refresh

          expect(sid0).not_to eq(nil)
          expect(sid1).to eq(sid0)
          expect(@worklist.transitions[sid0].state).to eq('allocated')
        end

        it 'creates a new transition if `force: true`' do

          t = @worklist.tasks.first

          sid0 = t.allocate('user', 'charly')
          t.refresh
          sid1 = t.allocate('user', 'bob', force: true)
          t.refresh

          expect(sid0).not_to eq(nil)
          expect(sid1).not_to eq(nil)
          expect(sid1).not_to eq(sid0)
          expect(@worklist.transitions[sid0].state).to eq('allocated')
          expect(@worklist.transitions[sid1].state).to eq('allocated')
        end
      end

      describe 'a transition to the another state' do

        it 'creates a new transition' do

          t = @worklist.tasks.first

          sid0 = t.last_transition.id
          sid1 = t.offer('user', 'orson')
          t.refresh
          sid2 = t.allocate('user', 'alice')
          t.refresh

          expect(sid0).not_to eq(nil)
          expect(sid1).not_to eq(nil)
          expect(sid2).not_to eq(nil)
          expect(sid2).not_to eq(sid0)

          s0 = @worklist.transitions[sid0]
          s1 = @worklist.transitions[sid1]
          s2 = @worklist.transitions[sid2]

          expect(s0.state).to eq('created')
          expect(s1.state).to eq('offered')
          expect(s2.state).to eq('allocated')

          expect(s0.domain).to eq('org.acme')
          expect(s1.domain).to eq('org.acme')
          expect(s2.domain).to eq('org.acme')
        end
      end

      describe 'pseudo-assignments' do

        they 'link assignments to the new transition' do

          t = @worklist.tasks.first

          t.offer('user', 'orson')
          t.refresh
          t.allocate(:first)
          t.refresh

          a = @worklist.assignments.first

          expect(a.transitions.collect(&:id)
            ).to eq(t.transitions[1..-1].collect(&:id))

          expect(t.transitions.collect { |s| s.assignments.collect(&:id) }
            ).to eq([ [], [ a.id ], [ a.id ] ])
          expect(t.last_transition.id
            ).to eq(t.transitions.last.id)
        end

        describe ':all' do

          it 'reuses all the assignments of the all transitions' do

            t = @worklist.tasks.first

            sid1 = t.offer('user', 'alice', refresh: true)
            t.offer('user', 'bob', r: true)
            sid2 = t.allocate([ 'user', 'celia' ], [ 'user', 'david' ], r: true)
            sid3 = t.offer('user', 'evan', r: true)
            t.offer('user', 'faye', r: true)
            sid4 = t.allocate(:all, r: true)

            expect(
              @worklist.assignments
                .order(:id)
                .collect { |a| [ a.resource_name, a.transition_ids ] }
            ).to eq([
              [ 'alice', [ sid1, sid4 ] ], [ 'bob', [ sid1, sid4 ] ],
              [ 'celia', [ sid2, sid4 ] ], [ 'david', [ sid2, sid4 ] ],
              [ 'evan', [ sid3, sid4 ] ], [ 'faye', [ sid3, sid4 ] ],
            ])
          end
        end

        describe ':current' do

          it 'reuses all the assignments of the last transition' do

            t = @worklist.tasks.first

            sid1 = t.offer('user', 'alice', refresh: true)
            t.offer('user', 'bob', r: true)
            sid2 = t.allocate([ 'user', 'celia' ], [ 'user', 'david' ], r: true)
            sid3 = t.offer('user', 'evan', r: true)
            t.offer('user', 'faye', r: true)
            sid4 = t.allocate(:current, r: true)

            expect(
              @worklist.assignments
                .order(:id)
                .collect { |a| [ a.resource_name, a.transition_ids ] }
            ).to eq([
              [ 'alice', [ sid1 ] ], [ 'bob', [ sid1 ] ],
              [ 'celia', [ sid2 ] ], [ 'david', [ sid2 ] ],
              [ 'evan', [ sid3, sid4 ] ], [ 'faye', [ sid3, sid4 ] ],
            ])
          end
        end

        describe ':first' do

          it 'reuses the first assignment of the current transition' do

            t = @worklist.tasks.first

            sid1 = t.offer([ 'user', 'alice' ], [ 'user', 'bob' ], r: true)
            sid2 = t.allocate(:first, r: true)

            s1 = @worklist.transitions[id: sid1]
            s2 = @worklist.transitions[id: sid2]

            expect(s1.assignments.collect(&:resource_name)
              ).to eq(%w[ alice bob ])
            expect(s2.assignments.collect(&:resource_name)
              ).to eq(%w[ alice ])
          end
        end

        describe ':last' do

          it 'reuses the last assignment of the current transition' do

            t = @worklist.tasks.first

            sid1 = t.offer([ 'user', 'alice' ], [ 'user', 'bob' ], r: true)
            sid2 = t.allocate(:last, r: true)

            s1 = @worklist.transitions[id: sid1]
            s2 = @worklist.transitions[id: sid2]

            expect(s1.assignments.collect(&:resource_name)
              ).to eq(%w[ alice bob ])
            expect(s2.assignments.collect(&:resource_name)
              ).to eq(%w[ bob ])
          end
        end

        describe '{id}' do

          it 'reuses the given assignment by id' do

            t = @worklist.tasks.first

            sid1 = t.offer([ 'user', 'alice' ], [ 'user', 'bob' ], r: true)
            a = @worklist.assignments.reverse(:id).first
            sid2 = t.allocate(a.id, r: true)

            s1 = @worklist.transitions[id: sid1]
            s2 = @worklist.transitions[id: sid2]

            expect(s1.assignments.collect(&:resource_name)
              ).to eq(%w[ alice bob ])
            expect(s2.assignments.collect(&:resource_name)
              ).to eq(%w[ bob ])
          end
        end

        describe '{assignment}' do

          it 'fails if the assignment is not linked to the task' do

            t0 = @worklist.tasks.order(:id).first

            exid1 = @unit.launch(%q{ bob _ })
            t1 = wait_until { @worklist.tasks[exid: exid1] }

            t0.offer([ 'user', 'alice' ], [ 'user', 'bob' ], r: true)
            t1.allocate([ 'user', 'alice' ])
            a = @worklist.assignments.reverse(:id).first

            expect {
              t0.allocate(a)
            }.to raise_error(
              Sequel::DatabaseError,
              "ArgumentError: assignment #{a.id} not linked to task #{t0.id}"
            )
          end

          it 'reuses the given assignment' do

            t = @worklist.tasks.first

            sid1 = t.offer([ 'user', 'alice' ], [ 'user', 'bob' ], r: true)
            a = @worklist.assignments.reverse(:id).first
            sid2 = t.allocate(a, r: true)

            s1 = @worklist.transitions[id: sid1]
            s2 = @worklist.transitions[id: sid2]

            expect(s1.assignments.collect(&:resource_name)
              ).to eq(%w[ alice bob ])
            expect(s2.assignments.collect(&:resource_name)
              ).to eq(%w[ bob ])
          end
        end

        describe ':none' do

          it 'forces the new transition to have no assignments' do

            t = @worklist.tasks.first

            sid1 = t.offer([ 'user', 'alice' ], [ 'user', 'bob' ], r: true)
            sid2 = t.allocate(:none, r: true)

            s1 = @worklist.transitions[id: sid1]
            s2 = @worklist.transitions[id: sid2]

            expect(s1.assignments.collect(&:resource_name)
              ).to eq(%w[ alice bob ])
            expect(s2.assignments.collect(&:resource_name)
              ).to eq(%w[])

            expect(@worklist.assignment_ds.count).to eq(2)
          end
        end

        describe ':self' do

          it 'assigns to self' do

            t = @worklist.tasks.first
            t.offer(:self, r: true)

            expect(t.assignments.count).to eq(1)
            expect(t.assignment.rtype).to eq('user')
            expect(t.assignment.rname).to eq('waldo')
          end

          it 'reuses assignments to self' do

            t = @worklist.tasks.first
            sid1 = t.offer(:self, r: true)
            sid2 = t.allocate('user', 'alice', r: true)
            sid3 = t.offer(:self, r: true)

            expect(t.assignments.count).to eq(1)
            expect(t.all_assignments.count).to eq(2)
            expect(t.assignment.transition_ids).to eq([ sid1, sid3 ])
          end
        end
      end

      describe 'a transition' do

        it 'defaults to :current' do

          t = @worklist.tasks.first

          sid1 = t.offer('user', 'alice', r: true)
          sid2 = t.allocate(r: true)
          s1 = @worklist.transitions[id: sid1]
          s2 = @worklist.transitions[id: sid2]

          expect(s1.assignments.collect(&:rname)).to eq(%w[ alice ])
          expect(s2.assignments.collect(&:rname)).to eq(%w[ alice ])
        end

        it 'accepts (:rtype, :rname)' do

          t = @worklist.tasks.first

          i = t.offer(:user, :alice, r: true)

          a = t.assignment

          expect(a.rtype).to eq('user')
          expect(a.rname).to eq('alice')
        end

        it 'accepts ([ :rt0, :rn0 ], [ :rt1, :rn1 ])' do

          t = @worklist.tasks.first

          i = t.offer([ :user, :alice ], [ :group, :glup ], r: true)

          as = t.assignments

          expect(as.collect(&:rtype)).to eq(%w[ user group ])
          expect(as.collect(&:rname)).to eq(%w[ alice glup ])
        end
      end

      describe '#transition_to_allocated / #allocate' do

        it 'adds an "allocated" transition to the task' do

          t = @worklist.tasks.first

          expect(t.tname).to eq('create')
          expect(t.state).to eq('created')

          sid = t.allocate('user', 'charly')
          t.refresh

          expect(t.last_transition.id).to eq(sid)
          expect(t.tname).to eq('allocate')
          expect(t.state).to eq('allocated')

          a = t.assignment
          as = t.assignments

          expect(a.rtype).to eq('user')
          expect(a.rname).to eq('charly')
          expect(as.size).to eq(1)
        end

        context 'payload:/fields:' do

          it 'places an updated payload in the transition row' do

            t = @worklist.tasks.first

            t.allocate(
              'user', 'charly',
              payload: t.payload.merge(name: 'leo'))
            t.refresh

            expect(t.state).to eq('allocated')
            expect(t.assignment.rname).to eq('charly')
            expect(t.payload).to eq('ret' => 'send message', 'name' => 'leo')
          end

          it 'places an updated payload in the transition row' do

            t = @worklist.tasks.first

            t.allocate('user', 'charly', payload: t.payload.merge(name: 'leo'))
            t.refresh
            t.allocate('user', 'david', payload: t.payload.merge(name: 'xen'))
            t.refresh

            d = t.transition.send(:_data)

            expect(d.size).to eq(2)

            expect(d[0]['payload'])
              .to eq('ret' => 'send message', 'name' => 'leo')
            expect(d[1]['payload'])
              .to eq('ret' => 'send message', 'name' => 'xen')
          end
        end
      end

      describe '#transition_to_offered / #offer' do

        it 'offers the task to a user' do

          t = @worklist.tasks.first

          expect(t.state).to eq('created')

          t.offer('user', 'charly')
          t.refresh

          expect(t.state).to eq('offered')

          as = t.assignments

          expect(as.size).to eq(1)

          a = t.assignment

          expect(a.rtype).to eq('user')
          expect(a.rname).to eq('charly')
        end

        it 'offers the task to 1 or more users' do

          t = @worklist.tasks.first

          t.offer([ 'user', 'charly' ], [ 'user', 'david' ])
          t.refresh

          expect(t.state).to eq('offered')

          as = t.assignments

          expect(as.size).to eq(2)

          a = t.assignment

          expect(a.rtype).to eq('user')
          expect(a.rname).to eq('charly')

          expect(as[0].rtype).to eq('user')
          expect(as[0].rname).to eq('charly')
          expect(as[1].rtype).to eq('user')
          expect(as[1].rname).to eq('david')
        end

        it 'offers the task to 1 or more users (2)' do

          t = @worklist.tasks.first

          t.offer(
            { rtype: 'user', rname: 'eve' },
            { resource_type: 'user', resource_name: 'frodo' })
          t.refresh

          expect(t.state).to eq('offered')

          as = t.assignments

          expect(as.size).to eq(2)

          expect(as[0].rtype).to eq('user')
          expect(as[0].rname).to eq('eve')
          expect(as[1].rtype).to eq('user')
          expect(as[1].rname).to eq('frodo')
        end
      end

      describe '#transition_to_started / #start' do

        it 'marks the task as started' do

          t = @worklist.tasks.first

          t.offer('user', 'bob', r: true)
          t.start(r: true)

          s = t.transition

          expect(s.assignments.size).to eq(1)
          expect(s.assignment.rname).to eq('bob')

          expect(s.assignment.transitions.collect(&:state)
            ).to eq(%w[ offered started ])
        end
      end

      describe '#transition_to_suspended / #suspend' do

        it 'fails if the task is not started' do

          t = @worklist.tasks.first

          t.offer('user', 'bob', r: true)

          expect {
            t.suspend
          }.to raise_error(
            Florist::ConflictError,
            "cannot suspend task #{t.id} " +
            "because it is currently \"offered\", not \"started\""
          )
        end

        it 'marks the task as suspended' do

          t = @worklist.tasks.first

          t.offer('user', 'bob', r: true)
          t.start(r: true)
          t.suspend(r: true)

          expect(t.transitions.count).to eq(4)
          expect(t.state).to eq('suspended')

          a = t.assignment

          expect(a.transitions.count).to eq(3)
          expect(a.rname).to eq('bob')
        end
      end

      describe '#transition_to_failed / #fail' do

        it 'marks the task as failed and replies to the execution' do

          t = @worklist.tasks.first

          t.offer('user', 'bob', r: true)
          t.fail(r: true)
          #t.fail(payload: { nada: 'surf' }, r: true)

          m = @unit.wait(t.exid, 'failed')

          expect(m['point']).to eq('failed')
          expect(m['exid']).to eq(t.exid)

          expect(@worklist.tasks[t.id]).to eq(nil)
        end

        context 'reply: false' do

          it 'marks the task as failed but does not reply' do

            mi = @unit.last_queued_message_id

            t = @worklist.tasks.first

            expect(t.transitions.count).to eq(1)

            t.offer('user', 'bob', r: true)
            t.fail(reply: false, r: true)

            sleep 1

            expect(@unit.last_queued_message_id).to eq(mi)

            t = @worklist.tasks[t.id]

            expect(t).not_to eq(nil)
            expect(t.transitions.count).to eq(3)
            expect(t.state).to eq('failed')
            expect(t.status).to eq('active')
          end
        end

        context 'status: x' do
          it 'places the task in status x after transition'
        end
      end

      describe '#transition_to_completed / #complete' do
        it 'marks the task as completed and replies to the execution'
        context 'reply: false' do
          it 'marks the task as completed but does not reply'
        end
        context 'status: x' do
          it 'places the task in status x after transition'
        end
      end
    end

    context 'more transitions' do

      before :each do

        @unit.add_tasker(
          'bob', Florist::WorklistTasker)

        @r = @unit.launch(
          %q{ bob 'send message' }, domain: 'org.acme', wait: 'task')

        wait_until { @worklist.task_ds.count == 1 }
      end

      describe '#resume' do

        it 'fails if the task is not paused' do

          t = @worklist.tasks.first

          expect {
            t.resume
          }.to raise_error(
            Florist::ConflictError,
            "cannot resume task #{t.id} " +
            "because it is currently \"created\", not \"suspended\""
          )
        end

        it 'brings back the task to started' do

          t = @worklist.tasks.first

          t.start('user', 'bob', r: true)
          t.suspend(r: true)
          t.resume(r: true)

          expect(t.transitions.count).to eq(4)
          expect(t.state).to eq('started')

          s = t.last_transition

          expect(s.state).to eq('started')
          expect(s.name).to eq('resume')

          a = t.assignment

          expect(a.transitions.count).to eq(3)
          expect(a.rname).to eq('bob')
        end
      end
    end

    context 'advanced transitions' do

#      before :each do
#
#        @unit.add_tasker(
#          'bob',
#          Florist::WorklistTasker)
#
#        @r = @unit.launch(
#          %q{
#            bob 'send message'
#          },
#          wait: 'task')
#
#        wait_until { @worklist.tasks.count == 1 }
#      end
    end

    context 'detour transitions' do

#      before :each do
#
#        @unit.add_tasker(
#          'bob',
#          Florist::WorklistTasker)
#
#        @r = @unit.launch(
#          %q{
#            bob 'send message'
#          },
#          wait: 'task')
#
#        wait_until { @worklist.tasks.count == 1 }
#      end
    end
  end
end

