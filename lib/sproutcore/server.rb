require "rack"
require "erubis"

module SproutCore
  class App
    def initialize(context, manifest)
      @context, @manifest = context, manifest
    end

    EXPIRES = (Time.now + (60 * 60 * 24 * 30)).rfc2822

    def response(content_type, body, expires = EXPIRES)
      body = body.is_a?(String) ? [body] : body
      [200, {"Content-Type" => content_type, "Expires" => expires}, body]
    end

    def call(env)
      url = env["PATH_INFO"]

      if url == "/"
        [200, {"Content-Type" => "text/html"}, [@context.render]]
      else
        url =~ %r{^/static/en/([^/]+)/(.*)$}

        target = $1
        type   = $2

        # TODO: HARDCODED
        if target == "todos"
          root = "/Users/wycats/Code/sprout/todos/apps/todos"
          body = File.read("#{root}/#{type}")

          if type =~ /\.js/
            content_type = "application/javascript"
          elsif type =~ /\.css/
            content_type = "text/css"
          end

          return response(content_type, body)
        end

        case type
        when "javascript.js"
          body = @manifest.find_js(target).compile
          response("application/javascript", body)
        when "stylesheet.css"
          body = @manifest.find_css(target).compile
          response("text/css", body)
        else
          if file = @manifest.find_static(type)
            response("application/octet-stream", File.open(file.source, "rb"))
          else
            [404, {"Content-Type" => "text/html"}, []]
          end
        end
      end
    end
  end

  class Server < ::Rack::Server
    def initialize
      sproutcore = File.expand_path("~/Code/sprout/sproutcore")
      @manifest   = SproutCore::Manifest.new

      # TODO: HARDCODED
      %w(bootstrap runtime foundation datastore statechart desktop media).each do |target|
        @manifest.add_target(sproutcore, target, :frameworks)
      end

      # TODO: HARDCODED
      @manifest.add_target(sproutcore, "standard_theme", :themes)

      template_location = File.expand_path("../templates/index.erb", __FILE__)
      template = Erubis::Eruby.new(File.read(template_location))

      HtmlContext.class_eval <<-RUBY, template_location, 0
        def render
          #{template.src}
        end
      RUBY

      @context = HtmlContext.new({}, @manifest)
    end

    def app
      App.new(@context, @manifest)
    end
  end
end


