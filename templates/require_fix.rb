# http://blog.s21g.com/articles/1448

def cleanup_path(path)
  if path.to_s.match(/^file:/) && path.is_a?(String)
    jar_path, inner_path = path.split('!', 2)
    inner_path = File.expand_path(inner_path)
    path = [jar_path, inner_path].join('!')
  end
  path
end

alias :require_original :require
def require(path)
  require_original cleanup_path(path)
rescue Exception => e
  raise e unless path.to_s.match(/^file:/)
end

alias :load_original :load
def load(path)
  load_original cleanup_path(path)
rescue Exception => e
  raise e unless path.to_s.match(/^file:/)
end

class Dir
  class << self
    alias :aref_original :[]
    def [](*args)
      aref_original *(args.map{|path| cleanup_path(path)})
    end
  end
end
class File
  class << self
    alias :mtime_original :mtime
    def mtime(path)
      if path.match(/^file:/)
        jar_file, = path.split('!', 2)
        path = jar_file.sub(/^file:/, '')
      end
      mtime_original(path)
    end
  end
end
