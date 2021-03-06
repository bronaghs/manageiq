
$:.push(File.expand_path(File.join(Rails.root, %w{.. lib Scvmm})))

class EmsMicrosoft < EmsInfra
  include_concern "Powershell"

  def self.default_host_type
    @default_host_type ||= "HostMicrosoft".freeze
  end

  def self.default_vm_type
    @default_vm_type ||= "VmMicrosoft".freeze
  end

  def self.default_template_type
    @default_template_type ||= "TemplateMicrosoft".freeze
  end

  def self.ems_type
    @ems_type ||= "scvmm".freeze
  end

  def self.description
    @description ||= "Microsoft System Center VMM".freeze
  end

  def self.raw_connect(username, password, auth_url)
    # HACK: WinRM depends on the gssapi gem for encryption purposes.
    # The gssapi code outputs the following warning:
    #   WARNING: Could not load IOV methods. Check your GSSAPI C library for an update
    #   WARNING: Could not load AEAD methods. Check your GSSAPI C library for an update
    # After much googling, this warning is considered benign and can be ignored.
    # Please note - the webmock gem depends on gssapi too and prints out the
    # above warning when rspec tests are run.
    silence_warnings { require 'winrm' }

    WinRM::WinRMWebService.new(auth_url, :ssl, :user => username, :pass => password, :disable_sspi => true)
  end

  def self.auth_url(ipaddress, port = nil)
    port ||= 5985
    "http://#{ipaddress}:#{port}/wsman"
  end

  def connect(options = {})
    raise "no credentials defined" if self.authentication_invalid?(options[:auth_type])

    username = options[:user] || authentication_userid(options[:auth_type])
    password = options[:pass] || authentication_password(options[:auth_type])
    ipaddress = options[:ipaddress] || self.ipaddress
    auth_url = self.class.auth_url(ipaddress, port)
    self.class.raw_connect(username, password, auth_url)
  end

  def verify_credentials(_auth_type = nil, options = {})
    raise MiqException::MiqHostError, "No credentials defined" if self.authentication_invalid?(options[:auth_type])

    begin
      connect.run_cmd("uname -a")
    rescue WinRM::WinRMHTTPTransportError # Error 401
      raise MiqException::MiqHostError, "Login failed due to a bad username or password."
    end

    true
  end
end
