class BumbleModelGenerator < Rails::Generator::NamedBase
  def manifest
    record do |m|
      m.template('bumble_model.rb', "app/models/#{@file_path}.rb", 
        :assigns => {:class_name => @class_name, :args => @args})
    end
  end
end
