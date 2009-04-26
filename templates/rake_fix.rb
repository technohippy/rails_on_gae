if defined? Rake
  module Rake
    class Application
      alias original_load_imports load_imports
      def load_imports
        @pending_imports.delete_if{|fn| fn.is_a?(Class)}
        original_load_imports
      end
    end
  end
end
