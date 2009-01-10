class AddSolids < ActiveRecord::Migration
  def self.up
    EventType.create :event => 'solids'
  end

  def self.down
    EventType.delete_all "event = 'solids'"
  end
end
