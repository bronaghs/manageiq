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

      collection.each do |item|
        @data[key] << item
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
        :deployment_label     => hardware['deploymentLabel']
        :deployment_locked    => hardware['deploymentLocked']
      }
    end

    # Parse a VM instance, where +instance+ is a hash of values returned by
    # the VirtualMachineManager#list method.
    #
    def parse_vm(vm)
      log_header = "MIQ(#{self.class.name}.#{__method__})"
      $log.info("#{log_header} #{__method__}")
      $log.info(instance)

      new_result = {
        :type            => vm['type']
        :uid_ems         => vm['id']
        :ems_ref         => vm['id']
        :name            => vm['name']
        :vendor          => "Microsoft",
        :raw_power_state => vm['instanceView']['powerState'],
        :hardware        => parse_hardware(vm)
      }

      return uid, new_result
    end
  end
end
