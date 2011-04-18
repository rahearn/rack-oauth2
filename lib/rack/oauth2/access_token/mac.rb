module Rack
  module OAuth2
    class AccessToken
      class MAC < AccessToken
        attr_required :secret, :algorithm
        attr_optional :timestamp, :nonce, :body_hash, :signature

        def token_response
          super.merge(
            :secret => secret,
            :algorithm => algorithm
          )
        end

        def verify!(request)
          BodyHash.new(request.post_params).verify!(request.body_hash)
          Signature.new(
            :token     => request.access_token,
            :secret    => self.secret,
            :algorithm => self.algorithm,
            :timestamp => request.timestamp,
            :nonce     => request.nonce,
            :body_hash => request.body_hash,
            :method    => request.method,
            :host      => request.host,
            :port      => request.port,
            :path      => request.path,
            :query     => request.query
          ).verify!(request.signature)
        end

        def get(url, headers = {}, &block)
          _headers_ = authenticate(:get, url, headers)
          RestClient.get url, _headers_, &block
        end

        def post(url, payload, headers = {}, &block)
          _headers_ = authenticate(:post, url, headers, payload)
          RestClient.post url, payload, _headers_, &block
        end

        def put(url, payload, headers = {}, &block)
          _headers_ = authenticate(:put, url, headers, payload)
          RestClient.put url, payload, _headers_, &block
        end

        def delete(url, headers = {}, &block)
          _headers_ = authenticate(:delete, url, headers)
          RestClient.delete url, _headers_, &block
        end

        private

        def authenticate(method, url, headers = {}, payload = {})
          _url_ = URI.parse(url)
          self.timestamp = Time.now.to_i
          self.nonce = ActiveSupport::SecureRandom.hex(16)
          self.body_hash = BodyHash.new(payload).calculate
          self.signature = Signature.new(
            :token     => self.access_token,
            :secret    => self.secret,
            :algorithm => self.algorithm,
            :timestamp => self.timestamp,
            :nonce     => self.nonce,
            :body_hash => self.body_hash,
            :method    => method,
            :host      => _url_.host,
            :port      => _url_.port,
            :path      => _url_.path,
            :query     => _url_.query
          ).calculate
          headers.merge(:HTTP_AUTHORIZATION => authorization_header)
        end

        def authorization_header
          header = "MAC"
          header << " token=\"#{access_token}\""
          header << " timestamp=\"#{timestamp}\""
          header << " nonce=\"#{nonce}\""
          header << " bodyhash=\"#{body_hash}\""
          header << " signature=\"#{signature}\""
        end
      end
    end
  end
end

require 'rack/oauth2/access_token/mac/body_hash'
require 'rack/oauth2/access_token/mac/signature'