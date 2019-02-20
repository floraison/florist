
#
# specifying florist
#
# Wed Feb 20 09:09:04 JST 2019
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
  end

  after :each do

    @unit.shutdown
  end

  describe '::UserTasker' do

    it 'assigns a task to a user' do

      @unit.add_tasker('alice', Florist::UserTasker)

      r = @unit.launch(
        %q{
          alice _
        },
        wait: 'task')

      expect(r['point']).to eq('task')
      expect(r['tasker']).to eq('alice')

      fts = @unit.storage.db[:florist_tasks].all
      ftas = @unit.storage.db[:florist_task_assignments].all

      expect(fts.size).to eq(1)
      expect(ftas.size).to eq(1)
    end
  end
end

