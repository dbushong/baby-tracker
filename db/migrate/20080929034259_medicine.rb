class Medicine < ActiveRecord::Migration
  def self.up
    EventType.create :event => 'meds'
  end

  def self.down
    EventType.delete_all "event = 'meds'"
  end
end
