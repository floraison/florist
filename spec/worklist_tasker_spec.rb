
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

    it 'may directly allocate to a user' do

      @unit.add_tasker(
        'alice',
        class: Florist::WorklistTasker,
        state: 'allocated',
        resource_type: 'user',
        resource_name: 'alice')

      r = @unit.launch(
        %q{
          alice _
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
      expect(t[:content]).not_to eq(nil)
      expect(t[:ctime]).not_to eq(nil)
      expect(t[:mtime]).not_to eq(nil)
      expect(t[:status]).to eq(nil)

      expect(s[:task_id]).to eq(t[:id])
      expect(s[:content]).to eq(nil)
      expect(s[:state]).not_to eq('allocated')

      expect(a[:transition_id]).to eq(s[:id])
      expect(a[:resource_type]).to eq('user')
      expect(a[:resource_name]).to eq('alice')
      expect(a[:content]).to eq(nil)
      expect(a[:ctime]).not_to eq(nil)
      expect(a[:mtime]).not_to eq(nil)
      expect(a[:status]).to eq('active')

      m = Flor::Storage.from_blob(t[:content])
      expect(m['point']).to eq('task')
      expect(m['m']).to eq(r['m'])
    end
  end
end

