
#
# specifying florist
#
# Sun May 12 08:10:34 JST 2019
#

require 'spec_helper'


describe '::Florist' do

  before :each do
    #
    # same as spec/worklist_dump_spec.rb

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

  describe '.dump' do

    before :each do

      @unit.launch(%q{ alice _ }, domain: 'com.acme')
      @unit.launch(%q{ alice _ }, domain: 'acme.org.test')
      @unit.launch(%q{ bob _ }, domain: 'acme.org')

      wait_until { @unit.executions.count == 3 }
    end

    it 'dumps' do

      r = Florist.dump(@worklist)

      #File.open('tmp/dump.json', 'wb') { |f| f.write(r) }

      h = JSON.load(r)

      expect(h['tasks'].count).to eq(3)
    end
  end

  describe '.load' do

    it 'loads' do

      expect(@worklist.tasks.count).to eq(0)

      r = Florist.load(@worklist, File.read('spec/dump.json'))

      expect(@worklist.tasks.count).to eq(
        3)
      expect(r).to eq(
        tasks: 3, transitions: 3, transitions_assignments: 0, assignments: 0)
    end
  end
end

