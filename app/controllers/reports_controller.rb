require 'ostruct'

class ReportsController < ApplicationController
  def index
    @title = 'Baby Reports'
  end

  def report
    begin
      from_date = parse_date(params[:from_date], false, true)
      to_date   = parse_date(params[:to_date], true)
    rescue ArgumentError
      flash[:message] = 'Invalid date format'
      redirect_to :action => :index
      return
    end


    case params[:commit]
    when 'Summary'
      summary(from_date, to_date)
    when 'Log'
      log(from_date, to_date)
    when 'Chart Spitup Grams by Day'
      chart_spitup_by_day(from_date, to_date)
    when 'Chart Spitup Grams by Week'
      chart_spitup_by_week(from_date, to_date)
    when 'Chart Diapers per Week'
      chart_diapers_per_week(from_date, to_date)
    when 'Long Naps'
      long_naps(from_date, to_date)
    else
      raise "'#{params[:commit]}' not yet implemented"
    end
  end

  def solids
    @title = 'Solids Fed'

    rows = Event.connection.select_rows(%q{
        SELECT notes, MIN(happened_at) 
          FROM events 
         WHERE notes IS NOT NULL AND notes <> '' AND event_type_id = 8 
      GROUP BY 1
      ORDER BY 2 DESC
    })
    @menus  = {}
    @combos = {}
    @foods  = {}

    for row in rows
      menu = row[0].gsub(/[\d.]+\S*\s+/, '')
      date = parse_date(row[1])

      @menus[menu] = date
      menu.split(/\s*&\s*/).sort.each {|c| @combos[c] = date }
      menu.split(/\s*[&+]\s*/).
        map {|f| f.gsub(/^(diluted|mashed)\s+|e?s$/, '') }.
        sort.each {|f| @foods[f] = date }
    end
  end

  def chart_spitup_by_dow
    @title = 'Spitup Grams by Day of Week'

    days = Event.by_type('spitup').not_today.all(
      :group  => "STRFTIME('%w', happened_at)",
      :select => "STRFTIME('%w', happened_at) dow, " +
                 'SUM(quantity) / COUNT(DISTINCT DATE(happened_at)) avg_spew'
    )

    data = (0..6).to_a.map do |i|
      day  = days.find {|e| e.dow.to_i == i }
      day ? day.avg_spew.to_i : 0
    end

    show_chart(compute_chart_attrs([data], Date::ABBR_DAYNAMES).merge(
      :cht  => :bvs,
      :chg  => '0,5',
      :chs  => '600x400',
      :chbh => '70,5'
    ))
  end

  def chart_diapers_by_hour
    @title = 'Diaper Changes by Hour'

    hod_sql = %q{STRFTIME('%H', happened_at)}
    hours = Event.by_type('pee', 'poop').not_today.all(
      :group  => hod_sql,
      :select => "#{hod_sql} hod, COUNT(*) num_changes"
    )

    hnums = (0..23).to_a
    data = hnums.map do |h|
      hour = hours.find {|e| e.hod.to_i == h }
      hour ? hour.num_changes.to_i : 0
    end

    show_chart(compute_chart_attrs([data], hnums.map{|h| h.to_s}).merge(
      :cht => :bvs,
      :chs => '800x375'
    ))
  end

  private #####################################################################

  def parse_date(str, eod = false, no_future = false)
    now = DateTime.now
    off = now.offset
    dt  = DateTime.parse(str).new_offset(off) - off
    dt += Rational(86399, 86400) if
      eod && dt.hour == 0 && dt.min == 0 && dt.sec == 0
    dt = DateTime.new(dt.year-1, dt.mon, dt.day, dt.hour, dt.min, dt.sec, off) \
      if no_future && dt > now
    dt
  end

  def long_naps(from, to)
    @title = 'Long Naps'

    events = Event.date_range(from, to).by_type('sleep', 'wakeup').all(
      :order   => 'happened_at'
    )

    naps  = []
    @days  = {}
    start = nil
    for event in events
      if event.type_name == 'sleep'
        start = event.happened_at
        next
      elsif !start
        next
      end

      finish = event.happened_at

      date = date_for_time(start)
      next unless date_for_time(finish) == date

      nap = OpenStruct.new(
        :start    => start,
        :finish   => finish,
        :duration => finish - start,
        :date     => date
      )

      @days[date] ||= []
      @days[date] << nap

      naps << nap
    end

    @dates = naps.sort {|b,a| a.duration <=> b.duration }.map {|n| n.date }.uniq

    render :action => :long_naps
  end

  def date_for_time(t)
    t -= 1.day if t.hour < 9
    t.strftime('%Y-%m-%d')
  end

  def chart_diapers_per_week(from, to)
    @title = 'Diapers per Week'

    wsql  = %q{STRFTIME('%Y-%W', happened_at)}
    weeks = Event.date_range(from, to).by_type('pee', 'poop').all(
      :group  => wsql,
      :select => "#{wsql} e_week, COUNT(*) num_diapers",
      :order  => wsql
    )

    attrs = compute_chart_attrs([weeks.map {|w| w.num_diapers.to_i }],
                                weeks.map {|w| w.e_week })
    #attrs[:chg]  = '5,10'
    show_chart(attrs)
  end

  def chart_spitup_by_day(from, to)
    @title = 'Spitup Grams by Day'

    days = Event.date_range(from, to).by_type('spitup').all(
      :group  => 'DATE(happened_at)',
      :select => 'DATE(happened_at) e_date, SUM(quantity) total_spew'
    )
    
    if days.size > 1
      from = parse_date(days[0].e_date)
      to   = parse_date(days[-1].e_date)
    end

    dates = (from..to).to_a
    data  = dates.map do |date|
      edate = days[0] && parse_date(days[0].e_date)
      if edate == date
        days.shift.total_spew.to_i
      else
        nil
      end
    end

    attrs = compute_chart_attrs([data], dates.map {|d| d.to_s(:md) })
    attrs[:chg]  = '5,10'
    show_chart(attrs)
  end

  def chart_spitup_by_week(from, to)
    @title = 'Spitup Grams by Week'

    weeks = Event.date_range(from, to).by_type('spitup').all(
      :group  => %q{STRFTIME('%Y-%W', happened_at)},
      :select => %q{STRFTIME('%Y-%W', happened_at) e_week, SUM(quantity) total_spew}
    )

    def week_to_i(str)
      y, w = str.split(/-/).map {|n| n.to_i}
      y * 100 + w
    end

    if weeks.size > 1
      from = week_to_i(weeks[0].e_week)
      to   = week_to_i(weeks[-1].e_week)
    else
      raise 'Too short a range; specify a wider date range'
    end

    wnums = (from..to).to_a

    data = wnums.map do |wnum|
      eweek = weeks[0]
      if week_to_i(eweek.e_week) == wnum
        weeks.shift.total_spew.to_i
      else
        nil
      end
    end

    attrs = compute_chart_attrs([data], wnums)
    show_chart(attrs)
  end

  def gaxis_data(attrs, max=10)
    vals = attrs.values
    vals.each_with_index do |val, j|
      if val.size > max
        nv   = []
        st   = val.size / max
        last = nil
        (0...(val.size)).step(val.size / max) do |i| 
          nv << val[i]
          last = i
        end
        nv << val[-1] unless last == val.size-1
        vals[j] = nv
      end
    end
    {
      :chxt => attrs.keys.join(','),
      :chxl => (0..(vals.size-1)).to_a.map {|n| "#{n}:|" + vals[n].join('|') }.join('|')
    }
  end

  def compute_chart_attrs(data_sets, x_labels = nil)
    chd, chds, min, max = gtext_scaled_encode(data_sets)
    axes = { :y => ((min/10)..(max/10)).to_a.map {|n| n * 10} }
    axes[:x] = x_labels if x_labels
    attrs = gaxis_data(axes)
    attrs[:chd]  = chd
    attrs[:chds] = chds
    attrs
  end

  # chooses the shortest
  def gdata_encode(dss)
    [
      gtext_encode(dss), 
      (gsimple_encode(dss) rescue nil),
    ].reject {|d| d.nil? }.min {|a,b| a.size <=> b.size }
  end

  def gtext_encode(data_sets)
    't:' + data_sets.map {|ds| ds.map {|n| n || -1 }.join(',') }.join('|')
  end

  def gtext_scaled_encode(data_sets)
    min = max = nil

    chd = 't:' + data_sets.map do |ds|
      min = max = nil
      ds.map do |n|
        if n
          min = n if min.nil? || n < min
          max = n if max.nil? || n > max
          n
        else
          -1
        end
      end.join(',')
    end.join('|')

    min = min / 10 * 10
    max = (max / 10.0).ceil * 10

    chds = data_sets.map { "#{min},#{max}" }.join(',')

    [ chd, chds, min, max ]
  end

  def gsimple_encode(data_sets)
    's:' + data_sets.map do |ds|
      ds.map do |n|
        if n.nil?
          '_'
        else
          case n.to_i
          when 0..25
            (n + 65).chr 
          when 26..51
            (n + 93).chr
          when 52..61
            (n - 52).to_s
          else
            raise ArgumentError, "value out of range for simple encoding: #{n}"
          end
        end
      end
    end.join(',')
  end

  def show_chart(attrs)
    attrs = {
      :chs => '600x500',
      :cht => 'lc',
    }.merge attrs
    url = 'http://chart.apis.google.com/chart?' +
      attrs.map {|k,v| "#{k}=#{v}" }.join('&')
      
    render :text => %{<img src="#{url}" />}, :layout => true
  end

  def log(from, to)
    @title = 'Baby Tracker Log'
    @events = Event.date_range(from, to).all(
      :include => :event_type,
      :order   => 'happened_at'
    ) 
    render :action => 'log'
  end

  def summary(from, to)
    @title = 'Baby Tracker Summary'

    events = Event.date_range(from, to).all :include => :event_type

    @days = []
    for event in events
      time = date = event.happened_at
      date = Time.local(date.year, date.month, date.day)
      if !@days.empty? && @days[-1].date == date
        day = @days[-1]
      else
        day = OpenStruct.new :date => date, :feedings => [], :total_spitup => 0
        @days.push(day)
      end

      feedings = day.feedings
      if event.type_name == 'feed'
        feedings.push(OpenStruct.new(
          :time => time, :spitup => 0, :pp => [], :meds => nil
        ))
      elsif feedings.empty?
        @days.pop
        next # stuff leftover from earlier feeding
      else
        feeding = feedings[-1]
        case event.type_name
        when 'pee'    then feeding.pp.push(1)
        when 'poop'   then feeding.pp.push(2)
        when 'spitup' 
          feeding.spitup   += event.quantity
          day.total_spitup += event.quantity
        when 'meds'   then feeding.meds = time
        end
      end
    end 

    render :action => :summary
  end
end
