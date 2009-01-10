Time::DATE_FORMATS[:pretty_short] = proc do |date|
  date.strftime('%I:%M%p on %A').gsub(/(^|\s)0/, '\1')
end
Time::DATE_FORMATS[:md]  = proc {|date| "#{date.mon}/#{date.day}" }
Time::DATE_FORMATS[:mdy] = proc {|date| "#{date.mon}/#{date.day}/#{date.year}" }
