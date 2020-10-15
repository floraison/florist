
#
# specifying florist
#
# Thu Oct 15 15:01:22 JST 2020
#

require 'spec_helper'


describe '::Florist::Worklist' do

  before :each do

    @engine_uri = storage_uri(:engine, delete: true)
    @worklist_uri = storage_uri(:worklist, delete: true)

    @unit = Flor::Unit.new(
      loader: Flor::HashLoader,
      sto_uri: @engine_uri,
      sto_migration_table: :flor_schema_info)
    @unit.conf['unit'] = 'tskspec'
    #@unit.hook('journal', Flor::Journal)
    @unit.storage.delete_tables
    @unit.storage.migrate
    @unit.start

    @unit.add_tasker(
      'alice', class: Florist::WorklistTasker, db_uri: @worklist_uri)
    @unit.add_tasker(
      'bob', class: Florist::WorklistTasker, db_uri: @worklist_uri)

    Florist.delete_tables(@worklist_uri)
    Florist.migrate(@worklist_uri)

    @worklist = Florist::Worklist.new(@unit, @worklist_uri)
  end

  after :each do

    @unit.shutdown
  end

  describe '#dump' do

    before :each do

      @unit.launch(%q{ alice _ }, domain: 'com.acme')
      @unit.launch(%q{ alice _ }, domain: 'acme.org.test')
      @unit.launch(%q{ bob _ }, domain: 'acme.org')

      wait_until { @unit.executions.count == 3 }
    end

    describe '()' do

      it 'dumps' do

        s = @worklist.dump

        h = JSON.load(s)

        expect(h.keys.sort).to eq(%w[
          assignments tasks timestamp transitions transitions_assignments ])
        expect(h['tasks'][0].keys.sort).to eq(%w[
          attls1 ctime data domain exid id mtime nid status tasker taskname ])
      end
    end
  end

  describe '#load' do

    describe '()' do

      it 'loads'
    end
  end
end
