
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
      expect(t[:status]).to eq(nil)

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

      m = Flor::Storage.from_blob(t[:content])
      expect(m['point']).to eq('task')
      expect(m['m']).to eq(r['m'])
    end

    context "@conf['allowed_overrides']" do

      it 'lets override conf from the execution'
    end
  end
end

