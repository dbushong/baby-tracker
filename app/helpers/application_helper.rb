# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def dump(obj)
    content_tag('pre', h(obj.inspect))
  end

  def hours_mins(secs)
    secs = secs.round
    parts = []
    if secs >= 3600
      parts << pluralize(secs / 3600, 'hour')
      secs %= 3600
    end

    mins = (secs / 60.0).round

    parts << pluralize(mins, 'minute') if mins > 0

    parts.empty? ? '0 minutes' : parts.join(' ')
  end
end
