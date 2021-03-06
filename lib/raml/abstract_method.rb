module Raml
  class AbstractMethod
    include Documentable
    include Parent

    attr_accessor :protocols

    def initialize(name, method_data, root)
      @children = []
      @name = name
      
      method_data.each do |key, value|
        case key
        when 'headers'
          validate_headers value
          @children += value.map { |h_name, h_data| Header.new h_name, h_data }

        when 'queryParameters'
          validate_query_parameters value
          @children += value.map { |p_name, p_data| Parameter::QueryParameter.new p_name, p_data }

        when 'body'
          validate_body value
          @children += value.map { |b_name, b_data| Body.new b_name, b_data, root }

        when 'responses'
          validate_responses value
          @children += value.map { |r_name, r_data| Response.new r_name, r_data, root }

        else
          begin
            send "#{Raml.underscore(key)}=", value
          rescue
            raise UnknownProperty, "#{key} is an unknown property."
          end
        end
      end

      validate
      set_defaults
    end
    
    def set_defaults
      self.protocols ||= []
    end

    def document
      lines = []
      lines << "####{}**#{@display_name || @name}**"
      lines << "#{@description}"

      lines << "Supported HTTP protocols: %s" % protocols.join(', ')

      if headers.any?
        lines << "**Headers:**"
        headers.values.each do |header|
          lines << header.document
        end
      end

      if query_parameters.any?
        lines << "**Query Parameters:**"
        query_parameters.values.each do |query_parameter|
          lines << query_parameter.document
        end
      end

      if bodies.any?
        lines << "**Body:**"
        bodies.values.each do |body|
          lines << body.document
        end
      end

      if responses.any?
        lines << "**Responses:**"
        responses.values.each do |response|
          lines << response.document
        end
      end

      lines.join "  \n"
    end

    children_by :headers          , :name       , Header
    children_by :query_parameters , :name       , Parameter::QueryParameter
    children_by :bodies           , :media_type , Body
    children_by :responses        , :name       , Response

    private
    
    def validate
      raise InvalidProperty, 'description property mus be a string' unless description.nil? or description.is_a? String
      
      validate_protocols
    end
    
    def validate_headers(headers)
      raise InvalidProperty, 'headers property must be a map' unless 
        headers.is_a? Hash
      
      raise InvalidProperty, 'headers property must be a map with string keys' unless
        headers.keys.all?  {|k| k.is_a? String }

      raise InvalidProperty, 'headers property must be a map with map values' unless
        headers.values.all?  {|v| v.is_a? Hash }      
    end
    
    def validate_protocols
      if protocols
        raise InvalidProperty, 'protocols property must be an array' unless
          protocols.is_a? Array
        
        raise InvalidProperty, 'protocols property must be an array strings' unless
          protocols.all? { |p| p.is_a? String }
        
        @protocols.map!(&:upcase)
        
        raise InvalidProperty, 'protocols property elements must be HTTP or HTTPS' unless 
          protocols.all? { |p| [ 'HTTP', 'HTTPS'].include? p }
      end
    end
    
    def validate_query_parameters(query_parameters)
      raise InvalidProperty, 'queryParameters property must be a map' unless 
        query_parameters.is_a? Hash
      
      raise InvalidProperty, 'queryParameters property must be a map with string keys' unless
        query_parameters.keys.all?  {|k| k.is_a? String }

      raise InvalidProperty, 'queryParameters property must be a map with map values' unless
        query_parameters.values.all?  {|v| v.is_a? Hash }      
    end

    def validate_body(body)
      raise InvalidProperty, 'body property must be a map' unless
        body.is_a? Hash
        
      raise InvalidProperty, 'body property must be a map with string keys' unless
        body.keys.all?  {|k| k.is_a? String }

      raise InvalidProperty, 'body property must be a map with map values' unless
        body.values.all?  {|v| v.is_a? Hash }
    end

    def validate_responses(responses)
      raise InvalidProperty, 'responses property must be a map' unless 
        responses.is_a? Hash
      
      raise InvalidProperty, 'responses property must be a map with integer keys' unless
        responses.keys.all?  {|k| k.is_a? Integer }

      raise InvalidProperty, 'responses property must be a map with map values' unless
        responses.values.all?  {|v| v.is_a? Hash }      
    end
  end
end
