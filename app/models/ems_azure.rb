class EmsAzure < EmsCloud
  include Vmdb::Logging
  alias_attribute :tenant_id, :uid_ems

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
    Azure::Armrest::ArmrestService.configure(
      :client_id  => clientid,
      :client_key => clientkey,
      :tenant_id  => tenantid
    )
  end

  def connect(options = {})
    raise "no credentials defined" if self.missing_credentials?(options[:auth_type])

    clientid  = options[:user] || authentication_userid(options[:auth_type])
    clientkey = options[:pass] || authentication_password(options[:auth_type])

    self.class.raw_connect(clientid, clientkey, tenant_id)
  end

  def verify_credentials(*)
    begin
      connect
    rescue RestClient::Unauthorized
      raise MiqException::MiqHostError, "Incorrect credentials - check your Azure Client ID and Client Key"
    rescue StandardError => err
      _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
      raise MiqException::MiqHostError, "Unexpected response returned from system, see log for details"
    end

    true
  end

  def vm_start(vm, _options = {})
    group = vm.uid_ems.split('\\').first
    vmm = ::Azure::Armrest::VirtualMachineService.new(vm.provider_object)
    vmm.start(vm.name, group)
    vmm.update_attributes!(:raw_power_state => "VM starting")
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_stop(vm, _options = {})
    group = vm.uid_ems.split('\\').first
    vmm = ::Azure::Armrest::VirtualMachineService.new(vm.provider_object)
    vmm.stop(vm.name, group)
    vmm.update_attributes!(:raw_power_state => "VM stopping")
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_restart(vm, _options = {})
    group = vm.uid_ems.split('\\').first
    vmm = ::Azure::Armrest::VirtualMachineService.new(vm.provider_object)
    vm.restart(vm.name, group)
    vmm.update_attributes!(:raw_power_state => "VM starting")
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end
end
