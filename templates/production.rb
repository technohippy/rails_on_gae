# Settings specified here will take precedence over those in config/environment.rb

# The production environment is meant for finished, "live" apps.
# Code is not reloaded between requests
config.cache_classes = true

# Enable threaded mode
#config.threadsafe!

class ServletContextAndStdoutLogger
  def debug(progname = nil, &block)
    log(:DEBUG, progname, &block)
  end

  def error(progname = nil, &block)
    log(:ERROR, progname, &block)
  end

  def fatal(progname = nil, &block)
    log(:FATAL, progname, &block)
  end

  def info(progname = nil, &block)
    log(:INFO, progname, &block)
  end

  def warn(progname = nil, &block)
    log(:WARN, progname, &block)
  end
  
  def log(severity, progname, &block)
    message = "#{severity}: #{progname || block.call}"
    STDOUT.puts message
    $servlet_context.log(message)
  end
  
  def method_missing(name, *args, &block)
  end
end

# Use a different logger for distributed setups
config.logger = ServletContextAndStdoutLogger.new

# Full error reports are disabled and caching is turned on
config.action_controller.consider_all_requests_local = false
config.action_controller.perform_caching             = true

# Use a different cache store in production
# config.cache_store = :mem_cache_store

# Enable serving of images, stylesheets, and javascripts from an asset server
# config.action_controller.asset_host                  = "http://assets.example.com"

# Disable delivery errors, bad email addresses will be ignored
# config.action_mailer.raise_delivery_errors = false
