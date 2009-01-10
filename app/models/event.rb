class Event < ActiveRecord::Base
  belongs_to :event_type

  validates_associated :event_type
  validates_numericality_of :quantity, :allow_nil => true, :only_integer => true
  validates_presence_of :happened_at, 
    :message => '(Time) must be YYYY-MM-DD HH:MM:SS'

  named_scope :date_range, lambda {|from, to| { 
    :conditions => ['happened_at BETWEEN ? AND ?', 
      from.to_s(:db), to.to_s(:db)],
    :order      => 'happened_at',
  } }

  named_scope :by_type, lambda {|*tname| {
    :conditions => { 'event_types.event' => tname },
    :joins    => :event_type,
  } }

  named_scope :not_today, 
    :conditions => %q{DATE(happened_at) <> DATE('now', 'localtime')}

  def type_name
    event_type.event
  end

  def self.last_created_at
    maximum(:created_at).dup.utc.to_i
  end
end
