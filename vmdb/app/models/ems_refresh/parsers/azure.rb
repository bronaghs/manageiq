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
      process_collection(vms, :vms) { |instance| parse_vm(vms) }
    end

    def process_collection(collection, key)
      @data[key] ||= []

      collection.each do |item|
        uid, new_result = yield(item)
        next if uid.nil?

        @data[key] << new_result
        @data_index.store_path(key, uid, new_result)
      end
    end


    def parse_image(image, is_public)
      uid      = image.id
      location = image.location
      guest_os = (image.platform == "windows") ? "windows" : "linux"

      name     = get_name_from_tags(image)
      name   ||= image.name
      name   ||= $1 if location =~ /^(.+?)(\.(image|img))?\.manifest\.xml$/
      name   ||= uid

      new_result = {
        :type            => "TemplateAmazon",
        :uid_ems         => uid,
        :ems_ref         => uid,
        :name            => name,
        :location        => location,
        :vendor          => "amazon",
        :raw_power_state => "never",
        :template        => true,
        # the is_public flag here avoids having to make an additional API call
        # per image, since we already know whether it's a public image
        :publicly_available => is_public,

        :hardware    => {
          :guest_os            => guest_os,
          :bitness             => ARCHITECTURE_TO_BITNESS[image.architecture],
          :virtualization_type => image.virtualization_type,
          :root_device_type    => image.root_device_type,
        },
      }

      return uid, new_result
    end

    def parse_vm(instance)
      log_header = "MIQ(#{self.class.name}.#{__method__})"
      $log.info("#{log_header} #{__method__}")

      status = instance.status
      return if @options["ignore_terminated_instances"] && status == :terminated

      uid    = instance.id
      name   = get_name_from_tags(instance)
      name ||= uid

      flavor_uid = instance.instance_type
      @known_flavors << flavor_uid
      flavor = @data_index.fetch_path(:flavors, flavor_uid) ||
        @data_index.fetch_path(:flavors, "unknown")

      private_network = {
        :ipaddress => instance.private_ip_address,
        :hostname  => instance.private_dns_name
      }.delete_nils

      public_network = {
        :ipaddress => instance.public_ip_address,
        :hostname  => instance.public_dns_name
      }.delete_nils

      parent_image = @data_index.fetch_path(:vms, instance.image_id)
      if parent_image
        virtualization_type = parent_image.fetch_path(:hardware, :virtualization_type)
        root_device_type    = parent_image.fetch_path(:hardware, :root_device_type)
      end

      new_result = {
        :type            => "VmAmazon",
        :uid_ems         => uid,
        :ems_ref         => uid,
        :name            => name,
        :vendor          => "amazon",
        :raw_power_state => status.to_s,

        :hardware    => {
          :bitness             => ARCHITECTURE_TO_BITNESS[instance.architecture],
          :virtualization_type => virtualization_type,
          :root_device_type    => root_device_type,
          :numvcpus            => flavor[:cpus],
          :cores_per_socket    => 1,
          :logical_cpus        => flavor[:cpus],
          :memory_cpu          => flavor[:memory] / (1024 * 1024), # memory_cpu is in megabytes
          :disk_capacity       => flavor[:disk_size],
          :disks               => [], # Filled in later conditionally on flavor
          :networks            => [], # Filled in later conditionally on what's available
        },

        :availability_zone   => @data_index.fetch_path(:availability_zones, instance.availability_zone),
        :flavor              => flavor,
        :cloud_network       => @data_index.fetch_path(:cloud_networks, instance.vpc_id),
        :cloud_subnet        => @data_index.fetch_path(:cloud_subnets, instance.subnet_id),
        :key_pairs           => [@data_index.fetch_path(:key_pairs, instance.key_name)].compact,
        :security_groups     => instance.security_groups.to_a.collect { |sg| @data_index.fetch_path(:security_groups, sg.id) }.compact,
        :orchestration_stack => @data_index.fetch_path(:orchestration_stacks, instance.tags["aws:cloudformation:stack-id"]),
      }
      new_result[:location] = public_network[:hostname] if public_network[:hostname]
      new_result[:hardware][:networks] << private_network.merge(:description => "private") unless private_network.blank?
      new_result[:hardware][:networks] << public_network.merge(:description => "public")   unless public_network.blank?

      if parent_image
        new_result[:parent_vm] = parent_image
        new_result.store_path(:hardware, :guest_os, parent_image.fetch_path(:hardware, :guest_os))
      end

      if flavor[:disk_count] > 0
        disks = new_result[:hardware][:disks]
        single_disk_size = flavor[:disk_size] / flavor[:disk_count]
        flavor[:disk_count].times do |i|
          add_instance_disk(disks, single_disk_size, i, "Disk #{i}")
        end
      end

      return uid, new_result
    end
  end
end
