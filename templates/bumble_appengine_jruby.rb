# original: http://github.com/olabini/bumble/tree/master
# modified by Ando Yasushi (andyjpn@gmail.com)
#   use the appengine_jruby wrapper instead of direct use of GAE/J
#require 'appengine-apis/datastore'

module Bumble
  module InstanceMethods
    def initialize(attrs = {}, *args)
      super(*args)
      @__entity = AppEngine::Datastore::Entity.new(self.class.name)
      attrs.each do |k,v|
        self.send "#{k}=", v
      end
    end

    def key
      __ds_key.get_id
    end
    
    def to_param
      self.key
    end
    
    def save!
      AppEngine::Datastore.put(@__entity)
    end

    def save
      save!
      true
    rescue
      false
    end
    
    def delete!
      self.class.delete(self.key)
    end

    def __ds_key
      @__entity.key
    end
    
    def __ds_get(name)
      name = name.to_s
      if @__entity.has_property(name)
        ret = @__entity.get_property(name)
        if ret.is_a?(AppEngine::Datastore::Text)
          ret.value
        else
          ret
        end
      else
        nil
      end
    end
    
    def __ds_set(name, value)
      if value.is_a?(String) && value.length > 499
        @__entity.set_property(name.to_s, AppEngine::Datastore::Text.new(value))
      else
        @__entity.set_property(name.to_s, value)
      end
    end
  end

  module ClassMethods
    def has_many(attr, type, key, options = {})
      type_name = (type.is_a?(Symbol) || type.is_a?(String)) ? type : type.name
      self.class_eval <<DEF
  def #{attr}
    #{type_name}.all({#{key.inspect} => self.key}, #{options.inspect})
  end
DEF
    end
    
    def belongs_to(attr, type)
      self.ds "#{attr}_id"
      type_name = (type.is_a?(Symbol) || type.is_a?(String)) ? type : type.name
      self.class_eval <<DEF
  def #{attr}
    if defined?(@#{attr})
      @#{attr}
    else 
      @#{attr} = if self.#{attr}_id
          #{type_name}.get(self.#{attr}_id)
        else
          nil
        end
    end
  end

  def #{attr}=(value)
    self.#{attr}_id = value.key
    @#{attr} = value
  end
DEF
    end
    
    # defines zero or more data store attributes - will create attribute accessors for these
    def ds(*names)
      names.each do |name|
        self.class_eval <<DEF
  def #{name}
    if defined?(@#{name})
      @#{name}
    else 
      @#{name} = __ds_get(#{name.inspect})
    end
  end

  def #{name}=(value)
    __ds_set(#{name.inspect}, value)
    @#{name} = value
  end
DEF
      end
    end

    def get(key)
      create_from_entity(AppEngine::Datastore.get(key))
    end
    
    def delete(key)
      AppEngine::Datastore.delete(key)
    end
    
    # returns either an object matching the conditions, or nil
    def find(conditions = {})
      query = AppEngine::Datastore::Query.new(self.name)      
      conditions.each do |k, v|
        query = query.filter(k.to_s, AppEngine::Datastore::Query::EQUAL, v)
      end

      result = query.entity
      if result
        create_from_entity(result)
      else
        result
      end
    end

    def create(attrs = {})
      val = new(attrs)
      val.save!
      val
    end
    
    def all(conditions = {}, options = {})
      q = AppEngine::Datastore::Query.new(self.name)
      conditions.each do |k, v|
        q = q.filter(k.to_s, AppEngine::Datastore::Query::EQUAL, v)
      end

      if options[:order]
        q.sort(options[:order])
        options.delete(:order)
      elsif options[:iorder]
        q.sort(options[:iorder], AppEngine::Datastore::Query::DESCENDING)
        options.delete(:iorder)
      end

      iter = q.iterator(options)
      
      iter.map do |ent|
        create_from_entity(ent)
      end
    end
    
    private
    def create_from_entity(ent)
      obj = self.new
      obj.instance_variable_set :@__entity, ent
      obj
    end
  end
  
  def self.included(base)
    base.send :include, InstanceMethods
    base.send :extend,  ClassMethods
  end
end
