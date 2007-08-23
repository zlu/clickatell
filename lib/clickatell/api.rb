require 'net/http'

module Clickatell
  # This module provides the core implementation of the Clickatell 
  # HTTP service.
  module API
    
    class << self
      
      # Authenticates using the specified credentials. Returns
      # a session_id if successful which can be used in subsequent
      # API calls.
      def authenticate(api_id, username, password)
        response = execute_command('auth',
          :api_id => api_id,
          :user => username,
          :password => password
        )
        parse_response(response)['OK']
      end
      
      # Pings the service with the specified session_id to keep the
      # session alive.
      def ping(session_id)
        execute_command('ping', :session_id => session_id)
      end
      
      # Sends a message +message_text+ to +recipient+. Recipient
      # number should have an international dialing prefix and
      # no leading zeros (unless you have set a default prefix
      # in your clickatell account centre).
      #
      # +auth_options+: a hash of credentials to be used in this
      # API call. Either api_id/username/password or session_id
      # for an existing authenticated session.
      #
      # Returns a new message ID if successful.
      def send_message(recipient, message_text, auth_options, opts={})
        valid_options = opts.only(:from)
        response = execute_command('sendmsg', {
          :to => recipient,
          :text => message_text
        }.merge(auth_hash(auth_options)).merge(valid_options)) 
        parse_response(response)['ID']
      end
      
      # Returns the status of a message. Use message ID returned
      # from original send_message call. See send_message() for
      # auth_options.
      def message_status(message_id, auth_options)
        response = execute_command('querymsg', {
          :apimsgid => message_id 
        }.merge( auth_hash(auth_options) ))
        parse_response(response)['Status']
      end
      
      # Returns the number of credits remaining as a float. 
      # See send_message() for auth_options.
      def account_balance(auth_options)
        response = execute_command('getbalance', auth_hash(auth_options))
        parse_response(response)['Credit'].to_f
      end

      protected
        # Builds a command and sends it via HTTP GET.
        def execute_command(command_name, parameters)
          Net::HTTP.get_response(
            Command.new(command_name).with_params(parameters)
          )
        end
        
        def parse_response(raw_response) #:nodoc:
          Clickatell::Response.parse(raw_response)
        end
        
        def auth_hash(options) #:nodoc:
          if options[:session_id]
            return {
              :session_id => options[:session_id]
            }
          else
            return {
              :user => options[:username],
              :password => options[:password],
              :api_id => options[:api_key]
            }
          end
      end
      
    end
    
    # Represents a Clickatell HTTP gateway command in the form 
    # of a complete URL (the raw, low-level request).
    class Command
      API_SERVICE_HOST = 'api.clickatell.com'

      def initialize(command_name, opts={})
        @command_name = command_name
        @options = { :secure => false }.merge(opts)
      end
      
      # Returns a URL for the given parameters (a hash).
      def with_params(param_hash)
        param_string = '?' + param_hash.map { |key, value| "#{key}=#{value}" }.sort.join('&')
        return URI.parse(File.join(api_service_uri, @command_name + URI.encode(param_string)))
      end

      protected
        def api_service_uri
          protocol = @options[:secure] ? 'https' : 'http'
          return "#{protocol}://#{API_SERVICE_HOST}/http/"
        end
    end
    
    # Clickatell API Error exception.
    class Error < StandardError
      attr_reader :code, :message
      
      def initialize(code, message)
        @code, @message = code, message
      end
      
      # Creates a new Error from a Clickatell HTTP response string
      # e.g.:
      #
      #  Error.parse("ERR: 001, Authentication error")
      #  # =>  #<Clickatell::API::Error code='001' message='Authentication error'>
      def self.parse(error_string)
        error_details = error_string.split(':').last.strip
        code, message = error_details.split(',').map { |s| s.strip }
        self.new(code, message)
      end
    end
    
  end
end