module VmAmazon::Operations::Power
  def validate_suspend
    validate_unsupported("Suspend Operation")
  end

  def validate_pause
    validate_unsupported("Pause Operation")
  end

  def raw_start
    with_provider_object { |instance| instance.start }
    # Temporarily update state for quick UI response until refresh comes along
    self.update_attributes!(:state => "suspended")
  end

  def raw_stop
    with_provider_object { |instance| instance.stop }
    # Temporarily update state for quick UI response until refresh comes along
    self.update_attributes!(:state => "suspended")
  end
end
