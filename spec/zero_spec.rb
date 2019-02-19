
#
# specifying florist
#
# Wed Feb 20 06:21:13 JST 2019
#

require 'spec_helper'


describe 'Florist' do

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
    @unit.conf['unit'] = 'floristspec'
    #@unit.hook('journal', Flor::Journal)
    @unit.storage.delete_tables
    @unit.storage.migrate(allow_missing_migration_files: true)
    @unit.start
  end

  after :each do

    @unit.shutdown
  end

  describe 'zero' do

    it 'initializes' do

      expect(@unit.class).to eq(Flor::Scheduler)
      expect(@unit.storage.db[:florist_tasks]).not_to eq(nil)
      expect(@unit.storage.db[:florist_task_assignments]).not_to eq(nil)
    end
  end
end

