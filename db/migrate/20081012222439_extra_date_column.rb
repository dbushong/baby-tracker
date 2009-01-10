class ExtraDateColumn < ActiveRecord::Migration
  def self.up
    add_column :events, :happened_at, :timestamp
    Event.reset_column_information
    Event.connection.execute('UPDATE events SET happened_at = created_at')
  end

  def self.down
    remove_column :events, :happened_at
  end
end
