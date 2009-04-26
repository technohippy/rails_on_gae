# http://github.com/olabini/bumble/tree/master
require 'java'

module Bumble
  module DS
    import com.google.appengine.api.datastore.DatastoreServiceFactory
    import com.google.appengine.api.datastore.Entity
    import com.google.appengine.api.datastore.FetchOptions
    import com.google.appengine.api.datastore.KeyFactory
    import com.google.appengine.api.datastore.Key
    import com.google.appengine.api.datastore.EntityNotFoundException
    import com.google.appengine.api.datastore.Query
    import com.google.appengine.api.datastore.Text
    Service = DatastoreServiceFactory.datastore_service
  end

  module InstanceMethods
    def initialize(attrs = {}, *args)
      super(*args)
      @__entity = DS::Entity.new(self.class.name)
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
      DS::Service.put(@__entity)
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
        if ret.is_a?(DS::Text)
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
        @__entity.set_property(name.to_s, DS::Text.new(value))
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
      create_from_entity(DS::Service.get(DS::KeyFactory.create_key(self.name, key.to_i)))
    end
    
    def delete(key)
      DS::Service.delete([DS::KeyFactory.create_key(self.name, key.to_i)].to_java(DS::Key))
    end
    
    # returns either an object matching the conditions, or nil
    def find(conditions = {})
      query = DS::Query.new(self.name)      
      conditions.each do |k, v|
        query = query.add_filter(k.to_s, DS::Query::FilterOperator::EQUAL, v)
      end

      result = DS::Service.prepare(query).asSingleEntity
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
      q = DS::Query.new(self.name)
      conditions.each do |k, v|
        q = q.add_filter(k.to_s, DS::Query::FilterOperator::EQUAL, v)
      end
      
      fo = nil
      
      if options[:limit]
        fo = DS::FetchOptions::Builder.with_limit(options[:limit])
      end

      if options[:offset]
        if fo
          fo = fo.offset(options[:offset])
        else
          fo = DS::FetchOptions::Builder.with_limit(options[:offset])
        end
      end
      
      if options[:order]
        q = q.add_sort(options[:order].to_s)
      end

      if options[:iorder]
        q = q.add_sort(options[:iorder].to_s, DS::Query::SortDirection::DESCENDING)
      end

      $servlet_context.log "doing search: #{q.to_s}"
      
      iter = if fo
               DS::Service.prepare(q).as_iterable(fo)
             else
               DS::Service.prepare(q).as_iterable
             end
      
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
