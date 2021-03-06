require_relative 'spec_helper'

describe Raml::Method do
  let(:name) { 'get' }
  let(:data) {
    YAML.load(%q(
      description: Get a list of users
      queryParameters:
        page:
          description: Specify the page that you want to retrieve
          type: integer
          required: true
          example: 1
        per_page:
          description: Specify the amount of items that will be retrieved per page
          type: integer
          minimum: 10
          maximum: 200
          default: 30
          example: 50
      protocols: [ HTTP, HTTPS ]
      responses:
        200:
          description: |
            The list of popular media.
    ))
  }
  let(:root) { Raml::Root.new 'title' => 'x', 'baseUri' => 'http://foo.com' }

  subject { Raml::Method.new(name, data, root) }

  describe '#new' do
    it "should instanciate Method" do
      subject
    end
    
    context 'when the method is a method defined in RFC2616 or RFC5789' do
      %w(options get head post put delete trace connect patch).each do |method|
        context "when the method is #{method}" do
          let(:name) { method }
          it { expect { subject }.to_not raise_error }
        end
      end
    end
    context 'when the method is an unsupported method' do
      %w(propfind proppatch mkcol copy move lock unlock).each do |method|
        context "when the method is #{method}" do
          let(:name) { method }
          it { expect { subject }.to raise_error Raml::InvalidMethod }
        end
      end
    end
    
    context 'when description property is not given' do
      let(:data) { {} }
      it { expect { subject }.to_not raise_error }
    end
    context 'when description property is given' do
      context 'when the description property is not a string' do
        let(:data) { { 'description' => 1 } }
        it { expect { subject }.to raise_error Raml::InvalidProperty, /description/ }
      end
      context 'when the description property is a string' do
        let(:data) { { 'description' => 'My Description' } }
        it { expect { subject }.to_not raise_error }
        it 'should store the value' do
          subject.description.should eq data['description']
        end
        it 'uses the description in the documentation' do
          subject.document.should include data['description']
        end
      end
    end
    
    context 'when the headers parameter is given' do
      context 'when the headers property is well formed' do
        let (:data) {
          YAML.load(%q(
            headers:
              Zencoder-Api-Key:
                displayName: ZEncoder API Key
              x-Zencoder-job-metadata-{*}:
                displayName: Job Metadata
          ))
        }
        it { expect { subject }.to_not raise_error }
        it 'stores all as Raml::Header instances' do
          expect( subject.headers.values ).to all( be_a Raml::Header )
          expect( subject.headers.keys   ).to contain_exactly('Zencoder-Api-Key','x-Zencoder-job-metadata-{*}')
        end
      end
      context 'when the headers property is not a map' do
        let(:data) { { 'headers' => 1 } }
        it { expect { subject }.to raise_error Raml::InvalidProperty, /headers/ }
      end
      context 'when the headers property is not a map with non-string keys' do
        let(:data) { { 'headers' => { 1 => {}} } }
        it { expect { subject }.to raise_error Raml::InvalidProperty, /headers/ }
      end
      context 'when the headers property is not a map with non-string keys' do
        let(:data) { { 'headers' => { '1' => 'x'} } }
        it { expect { subject }.to raise_error Raml::InvalidProperty, /headers/ }
      end
    end
    
    context 'when the protocols property is missing' do
      let(:data) { { } }
      it { expect{ subject }.to_not raise_error }
    end
    context 'when the protocols property is given' do
      context 'when the protocol property is not an array' do
        let(:data) { { 'protocols' => 'HTTP' } }
        it { expect{ subject }.to raise_error Raml::InvalidProperty, /protocols/ }
      end
      context 'when the protocol property is an array but not all elements are strings' do
        let(:data) { { 'protocols' => ['HTTP', 1] } }
        it { expect{ subject }.to raise_error Raml::InvalidProperty, /protocols/ }
      end
      context 'when the protocol property is an array of strings with invalid values' do
        let(:data) { { 'protocols' => ['HTTP', 'foo'] } }
        it { expect{ subject }.to raise_error Raml::InvalidProperty, /protocols/ }
      end
      [
        [ 'HTTP'  ],
        [ 'HTTPS' ],
        [ 'HTTP', 'HTTPS' ]
      ].each do |protocols|
        context "when the protocol property is #{protocols}" do
          let(:data) { { 'protocols' => protocols } }
          it { expect{ subject }.to_not raise_error }
          it 'stores the values' do
            subject.protocols.should eq protocols
          end
        end
      end
      context 'when the protocol property is an array of valid values in lowercase' do
        let(:data) { { 'protocols' => ['http', 'https'] } }
        it 'uppercases them' do
          subject.protocols.should eq [ 'HTTP', 'HTTPS' ]
        end
      end
    end
    
    context 'when a queryParameters property is given' do
      context 'when the queryParameters property is well formed' do
        let(:data) {
          YAML.load(
            %q(
              description: Get a list of users
              queryParameters:
                page:
                  description: Specify the page that you want to retrieve
                  type: integer
                  required: true
                  example: 1
                per_page:
                  description: Specify the amount of items that will be retrieved per page
                  type: integer
                  minimum: 10
                  maximum: 200
                  default: 30
                  example: 50
            )
          )
        }
        
        it { expect { subject }.to_not raise_error }
        it 'stores all as Raml::Parameter::UriParameter instances' do
          expect( subject.query_parameters.values ).to all( be_a Raml::Parameter::QueryParameter )
          subject.query_parameters.keys.should contain_exactly('page', 'per_page')
        end
      end
      context 'when the queryParameters property is not a map' do
        before { data['queryParameters'] = 1 }
        it { expect { subject }.to raise_error Raml::InvalidProperty, /queryParameters/ }
      end
      context 'when the queryParameters property is not a map with non-string keys' do
        before { data['queryParameters'] = { 1 => {}} }
        it { expect { subject }.to raise_error Raml::InvalidProperty, /queryParameters/ }
      end
      context 'when the queryParameters property is not a map with non-string keys' do
        before { data['queryParameters'] = { '1' => 'x'} }
        it { expect { subject }.to raise_error Raml::InvalidProperty, /queryParameters/ }
      end
    end

    context 'when a body property is given' do
      context 'when the body property is well formed' do
        let(:data) {
          YAML.load(
            %q(
            description: Create a Job
            body:
              text/xml:
                schema: job_xml_schema
              application/json:
                schema: json_xml_schema
            )
          )
        }
        
        it { expect { subject }.to_not raise_error }
        it 'stores all as Raml::Body instances' do
          expect( subject.bodies.values ).to all( be_a Raml::Body )
          subject.bodies.keys.should contain_exactly('text/xml', 'application/json')
        end
      end
      context 'when the body property is not a map' do
        before { data['body'] = 1 }
        it { expect { subject }.to raise_error Raml::InvalidProperty, /body/ }
      end
      context 'when the body property is a map with non-string keys' do
        before { data['body'] = { 1 => {}} }
        it { expect { subject }.to raise_error Raml::InvalidProperty, /body/ }
      end
      context 'when the body property is a map with non-map values' do
        before { data['body'] = { 'text/xml' => 1 } }
        it { expect { subject }.to raise_error Raml::InvalidProperty, /body/ }
      end
    end
    
    context 'when a responses property is given' do
      context 'when the responses property is well formed' do
        let(:data) {
          YAML.load(
            %q(
              responses:
                200:
                  body:
                    application/json:
                      example: !include examples/instagram-v1-media-popular-example.json
                503:
                  description: The service is currently unavailable.
            )
          )
        }
        
        it { expect { subject }.to_not raise_error }
        it 'stores all as Raml::Response instances' do
          expect( subject.responses.values ).to all( be_a Raml::Response )
          subject.responses.keys.should contain_exactly(200, 503)
        end
      end
      context 'when the responses property is not a map' do
        before { data['responses'] = 1 }
        it { expect { subject }.to raise_error Raml::InvalidProperty, /responses/ }
      end
      context 'when the responses property is not a map with non-integer keys' do
        before { data['responses'] = { '200' => {}} }
        it { expect { subject }.to raise_error Raml::InvalidProperty, /responses/ }
      end
      context 'when the responses property is not a map with non-string keys' do
        before { data['responses'] = { 200 => 'x'} }
        it { expect { subject }.to raise_error Raml::InvalidProperty, /responses/ }
      end
    end

    context 'when an is property is given' do
     let(:root) { 
        Raml::Root.new 'title' => 'x', 'baseUri' => 'http://foo.com',  'traits' => [
          { 'secured'     => {} },
          { 'paged'       => {} },
          { 'rateLimited' => {} }
        ]
      }
      context 'when the property is valid' do
        context 'when the property is an array of trait references' do
          let(:data) { { 'is' => [ 'secured', 'paged' ] } }
          it { expect { subject }.to_not raise_error }
          it 'should store the trait references' do
            subject.traits.should all( be_a Raml::TraitReference )
            subject.traits.map(&:name).should contain_exactly('secured', 'paged')
          end
        end
        context 'when the property is an array of trait references with parameters' do
          let(:data) { { 
            'is' => [ 
              {'secured' => {'tokenName' => 'access_token'}}, 
              {'paged'   => {'maxPages'  => 10            }} 
            ] 
          } }
          it { expect { subject }.to_not raise_error }
          it 'should store the trait references' do
            subject.traits.should all( be_a Raml::TraitReference )
            subject.traits.map(&:name).should contain_exactly('secured', 'paged')
          end
        end
        context 'when the property is an array of trait definitions' do
          let(:data) { { 
            'is' => [ 
              {'queryParameters' => {'tokenName' => {'description'=>'foo'}}}, 
              {'queryParameters' => {'numPages'  => {'description'=>'bar'}}}
            ] 
          } }
          it { expect { subject }.to_not raise_error }
          it 'should store the traits' do
            subject.traits.should all( be_a Raml::Trait )
            subject.traits.map(&:query_parameters).map(&:keys).flatten.should contain_exactly('tokenName', 'numPages')
          end
        end
        context 'when the property is an array of mixed trait refrences, trait refrences with parameters, and trait definitions' do
          let(:data) { { 
            'is' => [ 
              {'secured' => {'tokenName' => 'access_token'}}, 
              {'queryParameters' => {'numPages'  => {'description'=>'bar'}}},
              'rateLimited'
            ] 
          } }
          it { expect { subject }.to_not raise_error }
          it 'should store the traits' do
            subject.traits.select {|t| t.is_a? Raml::TraitReference }.map(&:name).should contain_exactly('secured', 'rateLimited')
            subject.traits.select {|t| t.is_a? Raml::Trait}.map(&:query_parameters).map(&:keys).flatten.should contain_exactly('numPages')
          end
        end
      end
      context 'when the property is invalid' do
        context 'when the property is not an array' do
          let(:data) { { 'is' => 1 } }
          it { expect { subject }.to raise_error Raml::InvalidProperty, /is/ }
        end
        context 'when the property is an array with elements other than a string or map' do
          let(:data) { { 'is' => [1] } }
          it { expect { subject }.to raise_error Raml::InvalidProperty, /is/ }
        end
        context 'when the property is an array an element that appears to be a trait name with parameters, but the params are not a map' do
          let(:data) { { 'is' => [ { 'secured' => 1 } ] } }
          it { expect { subject }.to raise_error Raml::InvalidProperty, /is/ }
        end
      end
    end
  end

  describe "#document" do
    it "prints out documentation" do
      subject.document
    end
  end
end
