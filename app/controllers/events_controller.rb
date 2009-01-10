require 'ostruct'

class EventsController < ApplicationController
  def index
    @title   = 'Baby Tracker'
    @recent  = Event.all(
      :order      => 'happened_at DESC, created_at DESC', 
      :conditions => "happened_at >= DATETIME('now','-24 hours', 'localtime')",
      :include    => :event_type
    )

    finish   = {}
    start    = {}
    @elapsed = {}
    for r in @recent
      etid = r.event_type_id
      if finish[etid]
        if !start[etid]
          start[etid] = true
          fin = finish[etid]
          finish.delete(etid)
          @elapsed[fin.id] = fin.happened_at - r.happened_at
        end
      else
        finish[etid] = r
      end
    end

    @timers = EventType.all(:order => 'event').map do |type|
      last = @recent.find {|e| e.event_type_id == type.id } ||
             Event.by_type(type.event).last(:order => 'happened_at')
      OpenStruct.new(
        :name    => type.event,
        :time    => last && (last.happened_at.dup.utc.to_i * 1000)
      )
    end

    @last_update = Event.last_created_at
  end

  def last_update
    render :json => Event.last_created_at
  end

  def create_simple
    now  = DateTime.now
    time = params[:time]
    time = nil if time.empty?
    if time && time =~ 
        /^(?:(\d{4})-(\d\d)-(\d\d)\s+)?([\d:]+)(?:\s*([ap])m?)?|-(\d+)$/i
      y, mo, d, hm, ap, minus = $1, $2, $3, $4, $5, $6
      if minus
        h, m = split_hm(minus)
        time = now - (Rational(h, 24) + Rational(m, 1440))
      else
        hm = hm.gsub(':', '').to_i
        ambig_hour = ambig_min = false
        if hm > 99
          h = (hm / 100).floor
          m = hm % 100
          if ap 
            h += 12 if ap.downcase == 'p' && h < 12
          elsif h < 12
            ambig_hour = true 
          end
        else
          ambig_min = true
          h = now.hour
          m = hm
        end
        if y && mo && d
          ambig_hour = ambig_min = false
        else
          y  = now.year
          mo = now.month
          d  = now.day
        end
        time = DateTime.new(y, mo, d, h, m, 0, now.offset)
        if time > now
          time -=
            if    ambig_hour then Rational(12, 24)
            elsif ambig_min  then Rational(1, 24)
            else                  1 ; end
        elsif ambig_hour && time < now - Rational(12, 24)
          time += Rational(12, 24)
        end
      end
    end

    type = EventType.find_by_event params[:commit].downcase

    # add wakeup 5 mins ago if we don't have one
    if type.event !~ /wakeup|meds|spitup/
      last_sleep = Event.by_type('sleep').last(:order => 'happened_at')
      if last_sleep
        last_wake = Event.by_type('wakeup').last(:order => 'happened_at')
        wtime = (time || DateTime.now) - Rational(5, 1440) # 5 mins ago
        if !last_wake || last_wake.happened_at < last_sleep.happened_at &&
            wtime > last_sleep.happened_at
          wake_id =
            if last_wake
              last_wake.event_type_id
            elsif type.event == 'wakeup'
              type.id
            else
              EventType.find_by_event('wakeup').id
            end
          Event.create :event_type_id => wake_id, :happened_at => wtime
        end
      end
    end

    event = Event.new :event_type => type
    event.happened_at = time || now
    event.quantity = params[:quantity].to_i unless params[:quantity].empty?
    event.notes    = params[:notes]         unless params[:notes].empty?
    event.save!

    redirect_to :action => :index
  end

  def edit
    @event = Event.find params[:id]
    @title = "Editing Event ID #{@event.id}"
  end

  def update
    @event = Event.find params[:id]
    if @event.update_attributes params[:event]
      flash[:message] = 'Event updated successfully'
      flash[:fade]    = true
      redirect_to events_path
    else
      render :action => 'edit'
    end
  end

  def destroy
    Event.find(params[:id]).destroy
    redirect_to events_url
  end

  private #####################################################################

  def split_hm(str)
    hm = str.gsub(':', '').to_i
    if hm > 99
      h = (hm / 100).floor
      m = hm % 100
    else
      h = 0
      m = hm
    end
    [h, m]
  end
end
