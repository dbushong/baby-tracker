class Init < ActiveRecord::Migration
  def self.up
    create_table :event_types do |t|
      t.string :event
    end
    EventType.create :event => 'pee'
    EventType.create :event => 'poop'
    EventType.create :event => 'spitup'
    EventType.create :event => 'sleep'
    EventType.create :event => 'wakeup'
    EventType.create :event => 'feed'

    create_table :events do |t|
      t.datetime   :created_at
      t.integer    :quantity
      t.text       :notes
      t.references :event_type
    end
  end

  def self.down
    drop_table :events
    drop_table :event_types
  end
end
