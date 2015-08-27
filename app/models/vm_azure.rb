class VmAzure < VmCloud
  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
  end

  #
  # Relationship methods
  #

  def disconnect_inv
    super

    # Mark all instances no longer found as terminated
    power_state == "off"
    save
  end

  def disconnected
    false
  end

  def disconnected?
    false
  end

  def self.calculate_power_state(raw_power_state)
    case raw_power_state.downcase
    when /running/, /starting/
      "On"
    when /stopped/, /stopping/
      "Off"
    else
      "Unknown"
    end
  end
end
