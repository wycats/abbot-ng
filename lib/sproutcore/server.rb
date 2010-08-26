module SproutCore
  class Server < ::Rack::Server
    def initialize
      @sproutcore = File.expand_path("~/Code/sprout/sproutcore")
      @manifest   = SproutCore::Manifest.new

      %w(bootstrap runtime foundation datastore statechart desktop media).each do |target|
        manifest.add_target(@sproutcore, target, :frameworks)
      end

      manifest.add_target(@sproutcore, "standard_theme", :themes)

      @template = Erubis::Eruby.new(File.read(File.expand_path("../templates/index.erb", __FILE__)))
    end

    def app
      path = ENV["PATH_INFO"]

    end
  end
end


