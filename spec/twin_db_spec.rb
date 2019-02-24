
#
# specifying florist
#
# Sun Feb 24 07:32:46 JST 2019
#

require 'spec_helper'


describe 'florist' do

  before :each do

    @uri0 = storage_uri(:zero)
    @uri1 = storage_uri(:one)
p @uri0
p @uri1

    @unit = Flor::Unit.new(
      loader: Flor::HashLoader,
      sto_uri: @uri0)
    @unit.conf['unit'] = 'tdbspec'
    #@unit.hook('journal', Flor::Journal)
    @unit.storage.delete_tables
    @unit.storage.migrate
    @unit.start

    @db1 = Sequel.connect(@uri1)

    Florist.delete_tables(@db1)
    Florist.migrate(@db1)
p Dir['tmp/*.db']
p @unit.storage.db.tables
p Sequel.connect(@uri0).tables
p @db1.tables
p Sequel.connect(@uri1).tables

    @unit.add_tasker(
      'alice',
      class: Florist::UserTasker, db_uri: @uri1)
  end

  after :each do

    @unit.shutdown
  end

  context 'execution db vs task db' do

    it 'works' do

      r = @unit.launch(
        %q{
          alice _
        },
        wait: 'task')

      expect(r['point']).to eq('task')
      expect(r['tasker']).to eq('alice')

      expect(@db0[:flor_executions].count).to eq(1)
      expect(@db1[:florist_tasks].count).to eq(1)
    end
  end
end

