
#
# specifying florist
#
# Sun Feb 24 07:32:46 JST 2019
#

require 'spec_helper'


describe 'florist' do

  before :each do

    @uri0 = storage_uri(:zero, delete: true)
    @uri1 = storage_uri(:one, delete: true)

    @unit = Flor::Unit.new(
      loader: Flor::HashLoader,
      sto_uri: @uri0)
    @unit.conf['unit'] = 'tdbspec'
    #@unit.hook('journal', Flor::Journal)
    @unit.storage.delete_tables
    @unit.storage.migrate
    @unit.start

    Florist.delete_tables(@uri1)
    Florist.migrate(@uri1)

    @unit.add_tasker(
      'alice',
      class: Florist::WorklistTasker, db_uri: @uri1)
  end

  after :each do

    @unit.shutdown
  end

  context 'flor db vs florist db' do

    it 'stores tasks in a separate database' do

      r = @unit.launch(
        %q{
          alice _
        },
        wait: 'task')

      expect(r['point']).to eq('task')
      expect(r['tasker']).to eq('alice')

      db0 = Sequel.connect(@uri0)
      db1 = Sequel.connect(@uri1)

      wait_until { db0[:flor_executions].count == 1 }

      expect(db0[:flor_executions].count).to eq(1)
      expect(db1[:florist_tasks].count).to eq(1)
    end
  end
end

