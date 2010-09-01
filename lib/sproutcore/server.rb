require "rack"
require "erubis"

module SproutCore
  class Application
    def initialize(context, apps)
      @context, @apps = context, apps
    end

    EXPIRES   = (Time.now + (60 * 60 * 24 * 30)).rfc2822
    MIMES     = {"png" => "image/png"}
    NOT_FOUND = [404, {"Content-Type" => "text/html"}, ["Not Found"]]

    def response(content_type, body, expires = EXPIRES)
      body = body.is_a?(String) ? [body] : body
      [200, {"Content-Type" => content_type, "Expires" => expires}, body]
    end

    def call(env)
      url    = env["PATH_INFO"]
      return NOT_FOUND if url =~ /favicon\.ico/

      static = url =~ %r{^/static/en/([^/]+)/(.*)$}

      target = $1
      type   = $2

      unless static
        app = url.sub(%r{^/}, '')

        if @apps.app?(app)
          return response("text/html", @context.render(app))
        else
          return NOT_FOUND
        end
      end

      app = @apps.app_for(target)

      case type
      when /\.js$/
        app.each_javascript do |list|
          body = list.content_for(url)
          return response("application/javascript", body) if body
        end
      when /\.css$/
        app.each_stylesheet do |list|
          body = list.content_for(url)
          return response("text/css", body) if body
        end
      else
        if file = app.find_static(type)
          response(MIMES[file.source[/^.*\.([^\.]*)$/, 1]], File.open(file.source, "rb"))
        else
          NOT_FOUND
        end
      end
    end
  end

  class Server < ::Rack::Server
    def initialize
      # TODO: HARDCODED
      sproutcore = File.expand_path("~/Code/sprout/sproutcore")
      @apps = SproutCore::Apps.new

      @apps.add_root(sproutcore)

      # TODO: HARDCODED
      @apps.add_root(File.expand_path("~/Code/sprout/todos"), false)

      template_location = File.expand_path("../templates/index.erb", __FILE__)
      template = Erubis::Eruby.new(File.read(template_location))

      HtmlContext.class_eval <<-RUBY, template_location, 0
        def render(app)
          @app = @apps.app_for(app)
          #{template.src}
        end
      RUBY

      @context = HtmlContext.new({}, @apps)
    end

    def app
      Application.new(@context, @apps)
    end
  end
end


