require 'erb'
require 'pathname'
PLUGIN_ROOT = Pathname.new(File.dirname(__FILE__)).parent

def template_path(filename)
  "#{PLUGIN_ROOT}/templates/#{filename}"
end

def template(filename, b=binding)
  ERB.new(File.read(template_path(filename))).result(b)
end

def cp_template(filename, dirname)
  cp(template_path(filename), "#{RAILS_ROOT}#{dirname}#{filename}")
end

def gsub_file(filename, src, dest)
  contents = File.new(filename).read.gsub(src, dest)
  File.open(filename, 'w') {|file| file.print contents}
end

namespace :gae do
  # Params: APPNAME, 
  desc 'Initialize for GAE/J'
  task :init do
    # create all jars
    FileList[template_path('jar/*.jar')].each do |filename|
      cp(filename, "#{RAILS_ROOT}/lib/")
    end

    # rewrite shebang from ruby to jruby
    gsub_file("script/generate", %r{^(#!(.*)[\s/])ruby}, '\1jruby')
    gsub_file("script/plugin", %r{^(#!(.*)[\s/])ruby}, '\1jruby')

    # create appengine-web.xml
    filename = 'appengine-web.xml'
    appname = ENV['APPNAME'] || Pathname.new(RAILS_ROOT).basename
    File.open("#{RAILS_ROOT}/#{filename}", 'w') {|file| file.print(template(filename, binding))}

    # copy templates
    cp_template('datastore-indexes.xml', '/')
    cp_template('production.rb', '/config/environments/')
    cp_template('bumble.rb', '/lib/')
    cp_template('beeu.rb', '/lib/')
    cp_template('rake_fix.rb', '/lib/')
    cp_template('require_fix.rb', '/lib/')

    # setup config/environment.rb
    filename = "#{RAILS_ROOT}/config/environment.rb"
    env = File.read(filename)
    env = <<-EOS + env
require 'lib/require_fix'
require 'lib/rake_fix'
#require 'lib/actionmailer-2.3.2.jar'
require 'lib/actionpack-2.3.2.jar'
#require 'lib/activerecord-2.3.2.jar'
#require 'lib/activeresource-2.3.2.jar'
require 'lib/activesupport-2.3.2.jar'
require 'lib/rails-2.3.2.jar'
require 'lib/jruby-openssl-0.4.jar'
require 'lib/bumble'
require 'lib/beeu'
RAILS_GEM_VERSION = '2.3.2'
    EOS
    env.sub! /^Rails::Initializer\.run.*$/, 
      "\\0\n  config.frameworks -= [ :active_record, :active_resource, :action_mailer ]"
    File.open(filename, 'w') {|file| file.print env}

    # warble
    sh 'warble pluginize'
    sh 'warble config'
    filename = "#{RAILS_ROOT}/config/warble.rb"
    warble = File.read(filename)
    warble.sub! /^end$/, <<-EOS
  config.gems -= ["rails"]
  config.includes = FileList['appengine-web.xml', 'datastore-indexes.xml']
  config.java_libs = []
  config.webxml.jruby.min.runtimes = 1
  config.webxml.jruby.max.runtimes = 1
  config.webxml.jruby.init.serial = true
end
    EOS
    File.open(filename, 'w') {|file| file.print warble}
  end

=begin
  namespace :update do
    desc 'Update jars for GAE/J SDK'
    task :gae do
    end

    desc 'Update jars for JRuby'
    task :jruby do
    end 

    desc 'Update jars for Rails'
    task :rails do
    end
  end

  desc 'Update war'
  task :deploy do
    `appcfg.sh update tmp/war`
    #sh 'appcfg.sh update tmp/war'
  end

  desc 'Deploy your app on the cloud'
  task :war do
    `jruby -S warble war`
    #sh 'warble war'
  end
=end
end
