require 'yaml'

module Raml
  class Parser
    def initialize(data, file_dir=Dir.getwd)
      register_include_tag
      
      @data = YAML.load data
      expand_includes @data, file_dir
      
      self
    end

    def parse
      @root = Root.new @data
    end
    
    private
    
    def register_include_tag
      YAML.add_tag '!include', Raml::Include
    end
    
    def expand_includes(val, cwd)
      case val
      when Hash
        val.merge!(val, &expand_includes_transform(cwd))
      when Array
        val.map!(&expand_includes_transform(cwd))
      end
    end
        
    def expand_includes_transform(cwd)
      proc do |arg1, arg2|
        val      = arg2 ? arg2 : arg1
        child_wd = cwd
        
        if val.is_a? Raml::Include
          child_wd = expand_includes_working_dir cwd, val.path
          val      = val.content cwd
        end
        
        expand_includes val, child_wd
        
        val
      end
    end
    
    def expand_includes_working_dir(current_wd, include_pathname)
      include_path = File.dirname include_pathname
      if include_path.start_with? '/'
        include_path
      else
        "#{current_wd}/#{include_path}"
      end
    end
  end
end
