
#
# specifying florist
#
# Wed Feb 27 06:49:56 JST 2019
#

require 'spec_helper'


describe '::Florist' do

  before :each do

    @unit = Flor::Unit.new(
      loader: Flor::HashLoader,
      sto_uri: storage_uri,
      sto_migration_table: :flor_schema_info)
    @unit.conf['unit'] = 'wlspec'
    #@unit.hook('journal', Flor::Journal)
    @unit.storage.delete_tables
    @unit.storage.migrate
    @unit.start

    Florist.delete_tables(storage_uri)
    Florist.migrate(storage_uri, table: :florist_schema_info)

    @unit.add_tasker('alice', Florist::WorklistTasker)

    @unit.launch(%q{ alice _ })

    wait_until { @unit.storage.db[:florist_tasks].count == 1 }
  end

  after :each do

    @unit.shutdown
  end

  describe '::Worklist' do

    describe '.initialize(db, conf)' do

      it 'instantiates a worklist' do

        l = Florist::Worklist.new(@unit.storage.db)

        expect(l.tasks.count).to eq(1)
        expect(l.tasks.first.class.ancestors).to include(Sequel::Model)
      end
    end

    describe '.initialize(unit)' do

      it 'instantiates a worklist' do

        l = Florist::Worklist.new(@unit)

        expect(l.tasks.count).to eq(1)
        expect(l.tasks.first.class.ancestors).to include(Sequel::Model)
      end
    end
  end
end

