require 'spec_helper.rb'

describe Rack::OAuth2::Server::Resource::MAC do
  let(:app) do
    Rack::OAuth2::Server::Resource::MAC.new(simple_app) do |request|
      case request.access_token
      when 'valid_token'
        Rack::OAuth2::AccessToken::MAC.new(
          :access_token => 'valid_token',
          :secret => 'secret',
          :algorithm => 'hmac-sha-256'
        ).verify!(request)
      when 'insufficient_scope_token'
        request.insufficient_scope!
      else
        request.invalid_token!
      end
    end
  end
  let(:access_token) { env[Rack::OAuth2::Server::Resource::ACCESS_TOKEN] }
  let(:request) { app.call(env) }
  subject { app.call(env) }

  shared_examples_for :non_mac_request do
    it 'should skip OAuth 2.0 authentication' do
      status, header, response = request
      status.should == 200
      access_token.should be_nil
    end
  end
  shared_examples_for :authenticated_mac_request do
    it 'should be authenticated' do
      status, header, response = request
      status.should == 200
      access_token.should == 'valid_token'
    end
  end
  shared_examples_for :unauthorized_mac_request do
    it 'should be unauthorized' do
      status, header, response = request
      status.should == 401
      header['WWW-Authenticate'].should include 'MAC'
      access_token.should be_nil
    end
  end
  shared_examples_for :bad_mac_request do
    it 'should be unauthorized' do
      status, header, response = request
      status.should == 400
      access_token.should be_nil
    end
  end

  context 'when no access token is given' do
    let(:env) { Rack::MockRequest.env_for('/protected_resource') }
    it 'should skip OAuth 2.0 authentication' do
      status, header, response = request
      status.should == 200
      access_token.should be_nil
    end
  end

  context 'when valid_token is given' do
    context 'when other required params are missing' do
      let(:env) { Rack::MockRequest.env_for('/protected_resource', 'HTTP_AUTHORIZATION' => 'MAC token="valid_token"') }
      it_behaves_like :unauthorized_mac_request
    end

    context 'when other required params are invalid' do
      let(:env) { Rack::MockRequest.env_for('/protected_resource', 'HTTP_AUTHORIZATION' => 'MAC token="valid_token", timestamp="1302361200", nonce="51e74de734c05613f37520872e68db5f", signature="invalid""') }
      it_behaves_like :unauthorized_mac_request
    end

    context 'when all required params are valid' do
      let(:env) { Rack::MockRequest.env_for('/protected_resource', 'HTTP_AUTHORIZATION' => 'MAC token="valid_token", timestamp="1302361200", nonce="51e74de734c05613f37520872e68db5f", signature="cK4sig+1Rb7w5Dtvadj6q9RqCFnY4/Y+dvaVjXlm5Wk="') }
      it_behaves_like :authenticated_mac_request
    end
  end

  context 'when invalid_token is given' do
    let(:env) { Rack::MockRequest.env_for('/protected_resource', 'HTTP_AUTHORIZATION' => 'MAC token="invalid_token"') }
    it_behaves_like :unauthorized_mac_request

    describe 'realm' do
      let(:env) { Rack::MockRequest.env_for('/protected_resource', 'HTTP_AUTHORIZATION' => 'MAC token="invalid_token"') }

      context 'when specified' do
        let(:realm) { 'server.example.com' }
        let(:app) do
          Rack::OAuth2::Server::Resource::MAC.new(simple_app, realm) do |request|
            request.unauthorized!
          end
        end
        it 'should use specified realm' do
          status, header, response = request
          header['WWW-Authenticate'].should include "MAC realm=\"#{realm}\""
        end
      end

      context 'otherwize' do
        it 'should use default realm' do
          status, header, response = request
          header['WWW-Authenticate'].should include "MAC realm=\"#{Rack::OAuth2::Server::Resource::DEFAULT_REALM}\""
        end
      end
    end
  end
end
