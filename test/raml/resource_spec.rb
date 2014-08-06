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

  subject { Raml::Resource.new(name, data) }

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
          expect( subject.uri_parameters ).to all( be_a Raml::Parameter::UriParameter )
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
                get:
                  queryParameters:
                    name:
                      type: string
          )
        )
      }
      it { expect { subject }.to_not raise_error }
      it 'stores all as Raml::Resource instances' do
        expect( subject.resources ).to all( be_a Raml::Resource )
        expect( subject.resources.map(&:name) ).to contain_exactly('/followers','/following', '/keys')
      end
      it 'retrieve resource by name' do
        expect( subject.resource('not_exists') ).to be_nil
        expect( subject.resource('followers') ).to be_a(Raml::Resource)
        expect( subject.resource('/followers') ).to be_a(Raml::Resource)
        expect( subject.resource('followers').resource('not_exists') ).to be_nil
        expect( subject.resource('keys').resource('{keyId}') ).to be_a(Raml::Resource)
        expect( subject.resource('keys').resource('/{keyId}') ).to be_a(Raml::Resource)
        expect( subject.resource('keys').resource('/{keyId}').method(:get) ).to be_a(Raml::Method)
      end
      it 'get all parents' do
        expect( subject.parent ).to be_nil
        expect( subject.resource('keys').resource('{keyId}').parent.name ).to eq('/keys')
        expect( subject.parents ).to eq([])
        expect( subject.resource('keys').resource('{keyId}').parents.length ).to eq(2)
        expect( subject.resource('keys').resource('{keyId}').method(:get).parents.length ).to eq(3)
        expect( subject.resource('keys').resource('{keyId}').method(:get).parents[0].name ).to eq('/{keyId}')
        expect( subject.resource('keys').resource('{keyId}').method(:get).parents[1].name ).to eq('/keys')
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
          expect( subject.base_uri_parameters ).to all( be_a Raml::Parameter::BaseUriParameter )
          subject.base_uri_parameters.map(&:name).should contain_exactly('apiDomain')
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
  end
  
  describe "#document" do
    it "prints out documentation" do
      subject.document
    end
  end
end
