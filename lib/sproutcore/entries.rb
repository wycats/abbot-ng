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

      Dir["#{@target_dir}/**/*.#{self.class.ext}"].each do |file|
        source = File.read(file)
        requires = source.scan(%r{sc_require\(\s*['"](.*)['"]\)}).flatten

        add Entry.new(file[%r{#{@target_dir}/(.*)\.#{self.class.ext}}, 1], requires, source)
      end

      # make it faster to look up an entry by name, since
      # dependencies are Strings
      @target       = target
      @target_type  = target_type
      @package      = File.basename(@directory)
    end

    def inspect
      "#<Entries: #{map(&:name).join(", ")}>"
    end

    def manifest(root_manifest)
      @manifest = root_manifest
      self
    end

    def add(entry)
      self << entry
      @entry_lookup[entry.name] = entry
    end

    def compile
      output = inject("") do |output, file|
        output << "/* >>>>>>>>>> BEGIN #{file.name}.#{self.class.ext} */\n"
        output << "#{file.source}\n"
      end
    end

    # sort first by the naming heuristics, then by dependencies
    def sort!
      # define sorting heuristics in a subclass
    end

  private
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

    def compile
      super << %[\nSC.bundleDidLoad("#{@package}/#{@target}");\n]
    end

    def sort!
      step1 = sort_by! do |entry|
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

    def destination(default = "javascript.js")
      super
    end
  end

  class CssEntries < Entries
    StaticEntry = Struct.new(:source, :destination)

    self.ext = "css"

    self.locale = "english"        # hardcode for now
    self.theme  = "standard_theme" # hardcode for now

    attr_accessor :statics

    def initialize(*)
      super

      @statics = {}

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

      @statics["#{$2}#{$3}#{$4}"] = entry
      @statics["#{$3}#{$4}"] = entry
      @statics["#{$2}#{$3}"] = entry
      @statics[$3] = entry
    end

    def static_or_fallback(static)
      @statics[static] || @manifest.find_static(static)
    end

    def sort!
      sort_by!(&:name)
    end

    def compile
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

    def destination(default = "stylesheet.js")
      super
    end
  end
end

__END__

puts Benchmark.measure {
Dir[File.expand_path("~/Code/sprout/sproutcore/frameworks/*")].each do |file|
  begin
    puts File.basename(file)
    puts Benchmark.measure { SproutCore::CssEntries.from_directory("~/Code/sprout/sproutcore", File.basename(file)).compile }
  rescue TSort::Cyclic => e
    puts "Could not sort #{File.basename(file)}: #{e.message}"
  end
end
}

__END__
puts Benchmark.measure {
Dir[File.expand_path("~/Code/sprout/sproutcore/frameworks/*")].each do |file|
  begin
    puts File.basename(file)
    puts Benchmark.measure { SproutCore::JavaScriptEntries.from_directory("~/Code/sprout/sproutcore", File.basename(file)).compile }
  rescue TSort::Cyclic => e
    puts "Could not sort #{File.basename(file)}: #{e.message}"
  end
end
}
