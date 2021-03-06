
require 'metasploit/framework/login_scanner/http'

module Metasploit
  module Framework
    module LoginScanner

      # Tomcat Manager login scanner
      class Axis2 < HTTP

        DEFAULT_PORT = 8080
        # Inherit LIKELY_PORTS,LIKELY_SERVICE_NAMES, and REALM_KEY from HTTP

        CAN_GET_SESSION = true
        PRIVATE_TYPES   = [ :password ]

        # (see Base#attempt_login)
        def attempt_login(credential)
          http_client = Rex::Proto::Http::Client.new(
            host, port, {}, ssl, ssl_version
          )

          result_opts = {
              credential: credential
          }
          begin
            http_client.connect
            body = "userName=#{Rex::Text.uri_encode(credential.public)}&password=#{Rex::Text.uri_encode(credential.private)}&submit=+Login+"
            request = http_client.request_cgi(
              'uri' => uri,
              'method' => "POST",
              'data' => body,
            )
            response = http_client.send_recv(request)

            if response && response.code == 200 && response.body.include?("upload")
              result_opts.merge!(status: Metasploit::Model::Login::Status::SUCCESSFUL, proof: response)
            else
              result_opts.merge!(status: Metasploit::Model::Login::Status::INCORRECT, proof: response)
            end
          rescue ::EOFError, Rex::ConnectionError, ::Timeout::Error
            result_opts.merge!(status: Metasploit::Model::Login::Status::UNABLE_TO_CONNECT)
          end

          Result.new(result_opts)

        end

        # (see Base#set_sane_defaults)
        def set_sane_defaults
          self.uri = "/axis2/axis2-admin/login" if self.uri.nil?
          @method = "POST".freeze

          super
        end

        # The method *must* be "POST", so don't let the user change it
        # @raise [RuntimeError]
        def method=(_)
          raise RuntimeError, "Method must be POST for Axis2"
        end

      end
    end
  end
end

