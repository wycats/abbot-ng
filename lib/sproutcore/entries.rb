require "tsort"

Entry = Struct.new(:name, :requires, :source) do

end

# Construct a special Array that uses the Ruby TSort
# module to sort files by their dependencies
module SproutCore
  class Entries < Array
    include TSort

    # TSort requires that tsort_each_node iterates through
    # all nodes. Since this is an Array, alias to each
    alias tsort_each_node each

    class << self
      attr_accessor :ext
      attr_accessor :locale
      attr_accessor :theme
    end

    LOCALE_MAP = {"en" => "english", "english" => "en"}

    # Create a new Entries list through Entries.from_directory
    def self.from_directory(dir, target, target_type = :frameworks)
      list = new(dir, target, target_type)
      list.sort!
    end

    def initialize(dir, target, target_type)
      @directory    = File.expand_path(dir)
      @target_dir   = "#{@directory}/#{target_type}/#{target}"
      @entry_lookup = {}

      # make it faster to look up an entry by name, since
      # dependencies are Strings
      @target       = target
      @target_type  = target_type
      @package      = File.basename(@directory)

      process_files
    end

    def process_files
      Dir["#{@target_dir}/**/*.#{self.class.ext}"].each do |file|
        next if file =~ %r{^#{@target_dir}/(debug|tests)}

        source = File.read(file)
        requires = source.scan(%r{\b(?:sc_)?require\(\s*['"](.*)['"]\)}).flatten

        add Entry.new(file[%r{#{@target_dir}/(.*)\.#{self.class.ext}}, 1], requires, source)
      end
    end

    def inspect
      "#<Entries: #{map(&:name).join(", ")}>"
    end

    def app(app)
      @app = app
      self
    end

    def add(entry)
      self << entry
      @entry_lookup[entry.name] = entry
    end

    # use combine to mark a target as combinable
    def combine(file)
      @combine = file
      self
    end

    def compile
      @compiled ||= begin
        output = inject("") do |output, file|
          output << "/* >>>>>>>>>> BEGIN #{file.name}.#{self.class.ext} */\n"
          output << "#{file.source}\n"
        end
      end
    end

    # sort first by the naming heuristics, then by dependencies
    def sort!
      # define sorting heuristics in a subclass
    end

    def content_for(file)
      destinations[file]
    end

    def destinations
      @destinations ||= begin
        if !any?
          {}
        elsif @combine
          {"#{destination_root}/#{@combine}" => compile }
        else
          results = {}
          each do |entry|
            results["#{destination_root}/#{entry.name}.#{self.class.ext}"] = entry.source
          end
          results
        end
      end
    end

  private
    # TODO: It seems like this part should be handled by the server, not the Entries
    def destination_root
      "/static/#{LOCALE_MAP[self.class.locale]}/#{@target}"
    end

    # TSort requires that tsort_each_child take in a node
    # and then yield back once for each dependency.
    def tsort_each_child(node)
      node.requires.each do |name|
        if entry = @entry_lookup[name]
          yield entry
        else
          puts "WARN: #{node.name} required #{name}, but it could not be found"
        end
      end
    end
  end

  class JavaScriptEntries < Entries
    self.ext = "js"

    self.locale = "english"        # hardcode for now

    def compile
      @compiled ||= begin
        each do |entry|
          entry.source.gsub!(/sc_super\(\s*\)/, "arguments.callee.base.apply(this, arguments)")
        end

        super << %[\nSC.bundleDidLoad("#{@package}/#{@target}");\n]
      end
    end

    def sort!
      sort_by! do |entry|
        sort_by = case entry.name
        # TODO: Allow preferred filename customization
        when %r{^(\w+\.)lproj/strings$}       then -3
        when "core"                           then -2
        when "utils"                          then -1
        when %r{^(lproj|resources)/.*_page$}  then  1
        when "main"                           then  2
        else                                        0
        end

        [sort_by, entry.name]
      end

      replace(tsort)
    end
  end

  class StaticEntries < Entries
    StaticEntry = Struct.new(:source, :destination)

    self.locale = "english"        # hardcode for now

    def initialize(*)
      @map = {}
      super
    end

    def process_files
      Dir["#{@target_dir}/**/*.{gif,jpg,png}"].each do |file|
        file =~ %r{^#{@directory}/#{@target_type}/#{@target}/(?:#{self.class.locale}\.lproj\/)?(.*)$}
        add_static(file, $1)
      end
    end

    def add_static(source, relative)
      # TODO: Deal with non-English locale getting overridden, probably by sorting the statics
      # before passing them in for processing
      relative =~ %r{^((?:#{self.class.locale}\.lproj|english\.lproj|resources)/)?(images/)?(.*)(\.(gif|jpg|png))$}

      destination = "#{destination_root}/#{$3}#{$4}"
      entry = StaticEntry.new(source, destination)

      @map["#{$2}#{$3}#{$4}"] = entry
      @map["#{$3}#{$4}"] = entry
      @map["#{$2}#{$3}"] = entry
      @map[$3] = entry
    end

    def find_static(name)
      @map[name]
    end
  end

  class CssEntries < Entries
    self.ext = "css"

    self.locale = "english"        # hardcode for now
    self.theme  = "standard_theme" # hardcode for now

    attr_accessor :statics

    def sort!
      sort_by!(&:name)
    end

    def associate_statics(statics)
      @statics = statics
      self
    end

    def static_or_fallback(name)
      @statics.find_static(name) || @app.find_static(name)
    end

    def compile
      @compiled ||= begin
        each do |entry|
          entry.source.gsub!(/(sc_static|static_url|sc_target)\(\s*['"](.+)['"]\s*\)/) do |resource|
            url = static_or_fallback($2)

            if url && url.destination
              "url('#{url.destination}')"
            else
              puts "WARN: static not found: #{$2} (from #{entry.name}"
            end
          end
        end

        super
      end
    end
  end
end

