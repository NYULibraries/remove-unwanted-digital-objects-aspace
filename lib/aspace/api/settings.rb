module ASpace
  module API
    class Settings
      attr_reader :settings
      def self.settings(settings)
        h = {}
        h[:base_uri] = settings['BASE_URI']
        h[:username] = settings['USER']
        h[:password] = settings ['password'] if settings.['password']
      end
    end
  end
end
