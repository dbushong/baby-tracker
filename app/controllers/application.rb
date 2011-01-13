# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery # :secret => 'fb134454fc922bc71bad265834f4adca'
  
  # See ActionController::Base for details 
  # Uncomment this to filter the contents of submitted sensitive data parameters
  # from your application log (in this case, all fields with names like "password"). 
  # filter_parameter_logging :password
  #

  before_filter :set_time_zone

  private

  def set_time_zone
    Time.zone = 'Pacific Time (US & Canada)'
    authenticate_with_http_basic do |user,pass|
      Time.zone = "Eastern Time (US & Canada)" if user == 'dawn'
      true
    end
  end
end
