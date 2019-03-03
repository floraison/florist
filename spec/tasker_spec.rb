
#
# specifying florist
#
# Wed Feb 20 09:09:04 JST 2019
#

require 'spec_helper'


describe '::Florist' do

  before :each do

    @unit = Flor::Unit.new(
      loader: Flor::HashLoader,
      sto_uri: storage_uri,
      sto_migration_dir: 'spec/migrations',
      sto_sparse_migrations: true)
    @unit.conf['unit'] = 'wltspec'
    #@unit.hook('journal', Flor::Journal)
    @unit.storage.delete_tables
    @unit.storage.migrate
    @unit.start
  end

  after :each do

    @unit.shutdown
  end

  describe '::WorklistTasker' do

    context 'by default' do

      it 'inserts a "created" task' do

        @unit.add_tasker(
          'alice',
          Florist::WorklistTasker)

        r = @unit.launch(
          %q{
            alice _
          },
          wait: 'task')

        expect(r['point']).to eq('task')

        ts = @unit.storage.db[:florist_tasks].all
        ss = @unit.storage.db[:florist_transitions].all
        as = @unit.storage.db[:florist_assignments].all

        expect(ts.size).to eq(1)
        expect(ss.size).to eq(1)
        expect(as.size).to eq(0)

        t, s = ts.first, ss.first

        expect(s[:state]).to eq('created')
      end
    end

    it 'may directly allocate to a user' do

      @unit.add_tasker(
        'alice',
        class: Florist::WorklistTasker,
        state: 'allocated',
        resource_type: 'user',
        resource_name: 'alice')

      r = @unit.launch(
        %q{
          alice 1 'do this or that'
        },
        wait: 'task')

      expect(r['point']).to eq('task')
      expect(r['tasker']).to eq('alice')

      ts = @unit.storage.db[:florist_tasks].all
      ss = @unit.storage.db[:florist_transitions].all
      as = @unit.storage.db[:florist_assignments].all

      expect(ts.size).to eq(1)
      expect(ss.size).to eq(1)
      expect(as.size).to eq(1)

      t, s, a = ts.first, ss.first, as.first

      expect(t[:exid]).to eq(r['exid'])
      expect(t[:nid]).to eq(r['nid'])
      expect(t[:tasker]).to eq('alice')
      expect(t[:taskname]).to eq('1')
      expect(t[:attls1]).to eq('do this or that')
      expect(t[:content]).not_to eq(nil)
      expect(t[:ctime]).to match(/\A20\d{2}-.+\.\d+Z\z/)
      expect(t[:mtime]).to eq(t[:ctime])
      expect(t[:status]).to eq('active')

      expect(s[:task_id]).to eq(t[:id])
      expect(s[:content]).to eq(nil)
      expect(s[:state]).to eq('allocated')
      expect(s[:ctime]).to eq(t[:ctime])
      expect(s[:mtime]).to eq(t[:ctime])

      expect(a[:transition_id]).to eq(s[:id])
      expect(a[:resource_type]).to eq('user')
      expect(a[:resource_name]).to eq('alice')
      expect(a[:content]).to eq(nil)
      expect(a[:ctime]).to eq(t[:ctime])
      expect(a[:mtime]).to eq(t[:ctime])
      expect(a[:status]).to eq('active')

      m = Flor::Storage.from_blob(t[:content])['message']
      expect(m['point']).to eq('task')
      expect(m['m']).to eq(r['m'])
    end

    context 'overrides: %w[ state rtype rname ]' do

      it 'lets override conf from the execution' do

        @unit.add_tasker(
          'alice',
          class: Florist::WorklistTasker,
          overrides: %w[ state resource_type resource_name ])

        r = @unit.launch(
          %q{
            alice 'heavy one' state: 'allocated' rtype: 'user' rname: 'Alice'
          },
          wait: 'task')

        expect(r['point']).to eq('task')
        expect(r['tasker']).to eq('alice')

        ts = @unit.storage.db[:florist_tasks].all
        ss = @unit.storage.db[:florist_transitions].all
        as = @unit.storage.db[:florist_assignments].all

        expect(ts.size).to eq(1)
        expect(ss.size).to eq(1)
        expect(as.size).to eq(1)

        t, s, a = ts.first, ss.first, as.first

        expect(t[:exid]).to eq(r['exid'])
        expect(t[:nid]).to eq(r['nid'])
        expect(t[:tasker]).to eq('alice')
        expect(t[:taskname]).to eq('heavy one')
        expect(t[:attls1]).to eq('heavy one')
        expect(t[:content]).not_to eq(nil)
        expect(t[:status]).to eq('active')

        expect(s[:task_id]).to eq(t[:id])
        expect(s[:state]).to eq('allocated')

        expect(a[:transition_id]).to eq(s[:id])
        expect(a[:resource_type]).to eq('user')
        expect(a[:resource_name]).to eq('Alice')
        expect(a[:status]).to eq('active')
      end
    end

    #context "user: true" do
    context "rtype: 'user'" do

      it 'offers the task to the user with the tasker name' do

        @unit.add_tasker(
          'margaret',
          class: Florist::WorklistTasker,
          rtype: 'user')

        r = @unit.launch(
          %q{
            margaret 'neutralize york'
          },
          wait: 'task')

        expect(r['point']).to eq('task')
        expect(r['tasker']).to eq('margaret')

        ts = @unit.storage.db[:florist_tasks].all
        ss = @unit.storage.db[:florist_transitions].all
        as = @unit.storage.db[:florist_assignments].all

        expect(ts.size).to eq(1)
        expect(ss.size).to eq(1)
        expect(as.size).to eq(1)

        t, s, a = ts.first, ss.first, as.first

        expect(t[:exid]).to eq(r['exid'])
        expect(t[:nid]).to eq(r['nid'])
        expect(t[:tasker]).to eq('margaret')
        expect(t[:taskname]).to eq('neutralize york')
        expect(t[:attls1]).to eq('neutralize york')
        expect(t[:content]).not_to eq(nil)
        expect(t[:status]).to eq('active')

        expect(s[:task_id]).to eq(t[:id])
        expect(s[:state]).to eq('offered')

        expect(a[:transition_id]).to eq(s[:id])
        expect(a[:resource_type]).to eq('user')
        expect(a[:resource_name]).to eq('margaret')
        expect(a[:status]).to eq('active')
      end
    end

    context "rtype: 'group'" do

      it 'allocates the task to the group with the tasker name' do

        @unit.add_tasker(
          'rm',
          class: Florist::WorklistTasker,
          state: 'allocated',
          rtype: 'role')

        r = @unit.launch(
          %q{
            rm 'get customer approval'
          },
          wait: 'task')

        expect(r['point']).to eq('task')
        expect(r['tasker']).to eq('rm')

        ts = @unit.storage.db[:florist_tasks].all
        ss = @unit.storage.db[:florist_transitions].all
        as = @unit.storage.db[:florist_assignments].all

        expect(ts.size).to eq(1)
        expect(ss.size).to eq(1)
        expect(as.size).to eq(1)

        t, s, a = ts.first, ss.first, as.first

        expect(t[:exid]).to eq(r['exid'])
        expect(t[:nid]).to eq(r['nid'])
        expect(t[:tasker]).to eq('rm')
        expect(t[:taskname]).to eq('get customer approval')
        expect(t[:attls1]).to eq('get customer approval')
        expect(t[:content]).not_to eq(nil)
        expect(t[:status]).to eq('active')

        expect(s[:task_id]).to eq(t[:id])
        expect(s[:state]).to eq('allocated')

        expect(a[:transition_id]).to eq(s[:id])
        expect(a[:resource_type]).to eq('role')
        expect(a[:resource_name]).to eq('rm')
        expect(a[:status]).to eq('active')
      end
    end
  end
end

