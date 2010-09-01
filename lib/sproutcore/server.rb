require "rack"
require "erubis"

module SproutCore
  class Application
    def initialize(context, apps)
      @context, @apps = context, apps
    end

    EXPIRES   = (Time.now + (60 * 60 * 24 * 30)).rfc2822
    NOT_FOUND = [404, {"Content-Type" => "text/html"}, ["Not Found"]]

    def response(content_type, body, expires = EXPIRES)
      body = body.is_a?(String) ? [body] : body
      [200, {"Content-Type" => content_type, "Expires" => expires}, body]
    end

    def call(env)
      url = env["PATH_INFO"]
      static = url =~ %r{^/static/(\w+)/([^/]+)/(.*)$}

      locale = $1
      target = $2
      file   = $3

      if static
        app = @apps.app_for(target)
        if content = app.content_for(url, file)
          return response(*content)
        end
      else
        app_name = url.sub(%r{^/}, '')

        if @apps.app?(app_name)
          return response("text/html", @context.render(app_name))
        end
      end

      NOT_FOUND
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


