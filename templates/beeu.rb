# http://github.com/olabini/beeu/tree/master
require 'java'

module BeeU
  module US
    import com.google.appengine.api.users.UserServiceFactory
    Service = UserServiceFactory.user_service
  end

  class << self
    def login(request)
      US::Service.create_login_url(request.url)
    end

    def logout(request)
      US::Service.create_logout_url(request.url)
    end
  end
  
  module InstanceMethods
    protected
    def assign_user
      if US::Service.user_logged_in?
        @user = US::Service.current_user
      end
    end

    def assign_admin_status
      @admin = US::Service.user_logged_in? && US::Service.user_admin?
    end
    
    def verify_admin_user
      unless US::Service.user_logged_in? && US::Service.user_admin?
        if US::Service.user_logged_in?
          render :text => "You are not allowed to do that"
        else
          redirect_to US::Service.create_login_url(request.url)
        end
      end
    end
  end

  module ClassMethods
    def require_admin(*actions)
      before_filter :verify_admin_user, :only => actions
    end
  end

  def self.included(base)
    base.send :include, InstanceMethods
    base.send :extend,  ClassMethods
  end
end
