class VmAzure < VmCloud

  def provider_object(connection = nil)
    connection ||= self.ext_management_system.connect
    connection.instances[self.ems_ref]
  end

  #
  # Relationship methods
  #

  def disconnect_inv
    super

    # Mark all instances no longer found as terminated
    self.power_state == "off"
    self.save
  end

  def disconnected
    false
  end

  def disconnected?
    false
  end

  def self.calculate_power_state(raw_power_state)
    case raw_power_state
    when "running"       then "on"
    when "powering_up"   then "powering_up"
    when "shutting_down" then "powering_down"
    when "pending"       then "suspended"
    when "terminated"    then "terminated"
    else                      "off"
    end
  end
end
