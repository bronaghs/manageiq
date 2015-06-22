
class EmsAzure < EmsCloud
  def self.ems_type
    @ems_type ||= "azure".freeze
  end

  def self.description
    @description ||= "Azure".freeze
  end

  def self.hostname_required?
    false
  end

  def self.raw_connect(clientid, clientkey, tenantid)
    $log.info("#{__FILE__} #{__method__} params clientid: #{clientid} clientkey: #{clientkey} tenantid: #{tenantid} ")

    vmm = Azure::ArmRest::VirtualMachineManager.new({:client_id => clientid, :client_key => clientkey, :tenant_id => tenantid })
    vmm.get_token
  end

  def connect(options = {})
    $log.info("#{__FILE__} #{__method__}")
    raise "no credentials defined" if self.missing_credentials?(options[:auth_type])

    clientid  = options[:user] || options[:client_id]  || self.authentication_userid(options[:auth_type])
    clientkey = options[:pass] || options[:client_key] || self.authentication_password(options[:auth_type])
    tenantid  = options[:hostname] || options[:tenant_id] || self.hostname

    self.class.raw_connect(clientid, clientkey, tenantid)
  end

  def verify_credentials(_auth_type = nil, options = {})
    true
  end


end
