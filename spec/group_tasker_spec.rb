
#
# specifying florist
#
# Fri Feb 22 06:58:10 JST 2019
#

require 'spec_helper'


describe '::Florist' do

  before :each do

    @unit = Flor::Unit.new(
      loader: Flor::HashLoader,
      sto_uri: storage_uri,
      sto_migration_dir: 'spec/migrations',
      sto_sparse_migrations: true)
    @unit.conf['unit'] = 'gtspec'
    #@unit.hook('journal', Flor::Journal)
    @unit.storage.delete_tables
    @unit.storage.migrate
    @unit.start
  end

  after :each do

    @unit.shutdown
  end

  describe '::GroupTasker' do

    it 'assigns a task to a group' do

      @unit.add_tasker('accounting', Florist::GroupTasker)

      r = @unit.launch(
        %q{
          accounting _
        },
        wait: 'task')

      expect(r['point']).to eq('task')
      expect(r['tasker']).to eq('accounting')

      ts = @unit.storage.db[:florist_tasks].all
      as = @unit.storage.db[:florist_task_assignments].all

      expect(ts.size).to eq(1)
      expect(as.size).to eq(1)

#      t, a = ts.first, as.first
#
#      expect(t[:exid]).to eq(r['exid'])
#      expect(t[:nid]).to eq(r['nid'])
#      expect(t[:ctime]).not_to eq(nil)
#      expect(t[:mtime]).not_to eq(nil)
#      expect(t[:status]).to eq('created')
#
#      expect(a[:task_id]).to eq(t[:id])
#      expect(a[:type]).to eq('')
#      expect(a[:resource_name]).to eq('alice')
#      expect(a[:resource_type]).to eq('user')
#      expect(a[:content]).to eq(nil)
#      expect(a[:ctime]).not_to eq(nil)
#      expect(a[:mtime]).not_to eq(nil)
#      expect(a[:status]).to eq('active')
#
#      m = Flor::Storage.from_blob(t[:content])
#      expect(m['m']).to eq(r['m'])
    end
  end
end

