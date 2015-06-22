# TODO: Separate collection from parsing (perhaps collecting in parallel a la RHEVM)

module EmsRefresh::Parsers
  class Azure < Cloud
    def self.ems_inv_to_hashes(ems, options = nil)
      self.new(ems, options).ems_inv_to_hashes
    end

    def initialize(ems, options = nil)
      @ems        = ems
      @connection = ems.connect
      @options    = options || {}
      @data       = {}
      @data_index = {}
    end

    def ems_inv_to_hashes
      log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{@ems.name}] id: [#{@ems.id}]"

      $log.info("#{log_header}...")
      get_vms
      $log.info("#{log_header}...Complete")

      @data
    end

    private

    def get_vms
      log_header = "MIQ(#{self.class.name}.#{__method__})"
      $log.info("#{log_header} #{__method__}")

      vms = @connection.get_vms
      process_collection(vms, :vms) { |instance| parse_vm(instance) }
    end

    def process_collection(collection, key)
      @data[key] ||= []

      return if collection.nil?

      collection.each do |item|
        uid, new_result = yield(item)
        @data[key] << item
        @data_index.store_path(key, uid, new_result)
      end
    end

    # Parse hardware information from the hardwareProfile setting.
    #
    def process_vm_hardware(vm)
      hardware = vm['properties']['hardwareProfile']

      {
        :platform_guest_agent => hardware['platformGuestAgent'],
        :size                 => hardware['size'],
        :deployment_name      => hardware['deploymentName'],
        :deployment_id        => hardware['deploymentId'],
        :deployment_label     => hardware['deploymentLabel'],
        :deployment_locked    => hardware['deploymentLocked']
      }
    end

    def process_vm_storage(vm)
      storage = vm['properties']['storageProfile']['operatingSystemDisk']

      {
        :disk_name        => storage['diskName'],
        :caching          => storage['caching'],
        :operating_system => storage['operatingSystem'],
        :io_type          => storage['ioType'],
        :image_name       => storage['sourceImageName'],
        :vhd_uri          => storage['vhdUri'],
        :id               => storage['storageAccount']['id'],
        :name             => storage['storageAccount']['name'],
        :type             => storage['storageAccount']['type']
      }
    end

    def process_vm_network(vm)
      vm['properties']['networkProfile']['inputEndpoints'].collect do |n|
        {
          :name     => n['endpointName'],
          :port     => n['publicPort'],
          :protocol => n['protocol'],
        }
      end
    end

    def process_vm_extensions(vm)
      vm['properties']['extensions'].collect do |ext|
        {
          :extension  => ext['extension'],
          :publisher  => ext['publisher'],
          :version    => ext['version'],
          :state      => ext['state'],
          :name       => ext['referenceName'],
          :parameters => ext['parameters']
        }
      end
    end

    # Parse a VM instance, where +instance+ is a hash of values returned by
    # the VirtualMachineManager#list method.
    #
    def parse_vm(vm)
      log_header = "MIQ(#{self.class.name}.#{__method__})"
      $log.info("#{log_header} #{__method__}")

      uid = vm.fetch('id')

      new_result = {
        :type            => 'VmAzure',
        :uid_ems         => uid,
        :ems_ref         => uid,
        :name            => vm.fetch('name'),
        :vendor          => "Microsoft",
        :raw_power_state => vm.fetch('properties')['instanceView']['powerState'],
        :hardware        => process_vm_hardware(vm),
        :storage         => process_vm_storage(vm),
        :network         => process_vm_network(vm),
        :extensions      => process_vm_extensions(vm)
      }

      return uid, new_result
    end
  end
end
