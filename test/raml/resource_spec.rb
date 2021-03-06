# encoding: UTF-8
require_relative 'spec_helper'

describe Raml::Resource do
  let(:name) { '/{id}' }
  let(:data) {
    YAML.load(%q(
      uriParameters:
        id:
          type: integer
          required: true
          example: 277102
      /processing_status:
        get:
          displayName: Processing status
          description: Получить статус загрузки
          responses:
            200:
              body:
                application/json:
                  example: |
                    {
                      "percent": 0,
                      "type": "download",
                      "status":"initial"
                    }
    ))
  }
  let(:root) { Raml::Root.new 'title' => 'x', 'baseUri' => 'http://foo.com' }

  subject { Raml::Resource.new(name, data, root) }

  describe '#new' do
    it "should instanciate Resource" do
      subject
    end
    
    context 'when displayName is not given' do
      let(:data) { {} }
      it { expect { subject }.to_not raise_error }
      it 'uses the resource relative URI in the documentation' do
        subject.document.should include name
      end
    end
    context 'when displayName is given' do
      let(:data) { { 'displayName' => 'My Name'} }
      it { expect { subject }.to_not raise_error }
      it 'should store the value' do
        subject.display_name.should eq data['displayName']
      end
      it 'uses the displayName in the documentation' do
        subject.document.should include data['displayName']
      end
    end
    
    context 'when description is not given' do
      let(:data) { {} }
      it { expect { subject }.to_not raise_error }
    end
    context 'when description is given' do
      context 'when the description property is not a string' do
        let(:data) { { 'description' => 1 } }
        it { expect { subject }.to raise_error Raml::InvalidProperty, /description/ }
      end
      context 'when the description property is a string' do
        let(:data) { { 'description' => 'My Description'} }
        it { expect { subject }.to_not raise_error }
        it 'should store the value' do
          subject.description.should eq data['description']
        end
        it 'uses the description in the documentation' do
          subject.document.should include data['description']
        end
      end
    end
    
    context 'when the uriParameters parameter is given with valid parameters' do
      context 'when the uriParameters property is well formed' do
        it { expect { subject }.to_not raise_error }
        it 'stores all as Raml::Parameter::UriParameter instances' do
          expect( subject.uri_parameters.values ).to all( be_a Raml::Parameter::UriParameter )
        end
      end
      context 'when the uriParameters property is not a map' do
        let(:data) { { 'uriParameters' => 1 } }
        it { expect { subject }.to raise_error Raml::InvalidProperty, /uriParameters/ }
      end
      context 'when the uriParameters property is not a map with non-string keys' do
        let(:data) { { 'uriParameters' => { 1 => {}} } }
        it { expect { subject }.to raise_error Raml::InvalidProperty, /uriParameters/ }
      end
      context 'when the uriParameters property is not a map with non-string keys' do
        let(:data) { { 'uriParameters' => { '1' => 'x'} } }
        it { expect { subject }.to raise_error Raml::InvalidProperty, /uriParameters/ }
      end
    end
    
    context 'when nested resources are defined' do
      let(:name) { '/{userId}' }
      let(:data) {
        YAML.load(
          %q(
            uriParameters:
              userId:
                type: integer
            /followers:
              displayName: Followers
            /following:
              displayName: Following
            /keys:
              /{keyId}:
                uriParameters:
                  keyId:
                    type: integer
          )
        )
      }
      it { expect { subject }.to_not raise_error }
      it 'stores all as Raml::Resource instances' do
        expect( subject.resources.values ).to all( be_a Raml::Resource )
        expect( subject.resources.keys   ).to contain_exactly('/followers','/following', '/keys')
      end
    end
    
    context 'when a baseUriParameters property is given' do
      context 'when the baseUriParameters property is well formed' do
        let(:name) { '/files' }
        let(:data) {
          YAML.load(
            %q(
              displayName: Download files
              baseUriParameters:
                apiDomain:
                  enum: [ "api-content" ]
            )
          )
        }
        
        it { expect { subject }.to_not raise_error }
        it 'stores all as Raml::Parameter::UriParameter instances' do
          expect( subject.base_uri_parameters.values ).to all( be_a Raml::Parameter::BaseUriParameter )
          subject.base_uri_parameters.keys.should contain_exactly('apiDomain')
        end
      end
      context 'when the baseUriParameters property is not a map' do
        before { data['baseUriParameters'] = 1 }
        it { expect { subject }.to raise_error Raml::InvalidProperty, /baseUriParameters/ }
      end
      context 'when the baseUriParameters property is not a map with non-string keys' do
        before { data['baseUriParameters'] = { 1 => {}} }
        it { expect { subject }.to raise_error Raml::InvalidProperty, /baseUriParameters/ }
      end
      context 'when the baseUriParameters property is not a map with non-string keys' do
        before { data['baseUriParameters'] = { '1' => 'x'} }
        it { expect { subject }.to raise_error Raml::InvalidProperty, /baseUriParameters/ }
      end
      context 'when the baseUriParameters property has a key for the reserved "version" parameter' do
        before { data['baseUriParameters'] = { 'version' => {}} }
        it { expect { subject }.to raise_error Raml::InvalidProperty, /baseUriParameters/ }
      end
    end

    context 'when an type property is given' do
     let(:root) { 
        Raml::Root.new 'title' => 'x', 'baseUri' => 'http://foo.com',  'resourceTypes' => [
          { 'collection'        => {} },
          { 'member'            => {} },
          { 'auditableResource' => {} }
        ]
      }
      context 'when the property is valid' do
        context 'when the property is a resource type reference' do
          before { data['type'] = 'collection' }
          it { expect { subject }.to_not raise_error }
          it 'should store the resource type reference' do
            subject.type.should be_a Raml::ResourceTypeReference
            subject.type.name.should == 'collection'
          end
        end
        context 'when the property is a resource type reference with parameters' do
          before { data['type'] = {'collection' => {'maxSize' => 10}} }
          it { expect { subject }.to_not raise_error }
          it 'should store the resource type reference' do
            subject.type.should be_a Raml::ResourceTypeReference
            subject.type.name.should == 'collection'
          end
        end
        context 'when the property is a resource type definitions' do
          let(:definition) {
            YAML.load(%q(
              usage: This resourceType should be used for any collection of items
              description: The collection of <<resourcePathName>>
              get:
                description: Get all <<resourcePathName>>, optionally filtered
            ))
          }
          before { data['type'] = definition }

          it { expect { subject }.to_not raise_error }
          it 'should store the resource type' do
            subject.type.should be_a Raml::ResourceType
            subject.type.usage.should == definition['usage']
          end
        end
      end
      context 'when the property is invalid' do
        context 'when the type property is not a string or a map' do
          before { data['type'] = 1 }
          it { expect { subject }.to raise_error Raml::InvalidProperty, /type/ }
        end
        context 'when the property is a resource type name with parameters, but the params are not a map' do
          before { data['type'] = { 'collection' => 1 } }
          it { expect { subject }.to raise_error Raml::InvalidProperty, /type/ }
        end
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
            subject.traits.select {|t| t.is_a? Raml::Trait }.map(&:query_parameters).map(&:keys).flatten.should contain_exactly('numPages')
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
