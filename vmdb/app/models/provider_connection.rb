class ProviderConnection < ActiveRecord::Base
  attr_accessible :ipaddress, :port, :provider_component, :hostname
  belongs_to :ext_management_system, :foreign_key => "ems_id", :polymorphic => true

  include AuthenticationMixin

  def verify_credentials(auth_type = nil, options = {})
    raise MiqException::MiqHostError, "No credentials defined" if self.authentication_invalid?
    ems = ExtManagementSystem.find_by_id(ems_id)

    ems.verify_credentials(auth_type, make_options_hash(auth_type))
  end

  def make_options_hash(auth_type = nil)
    {
      :user      => username,
      :password  => password,
      :ipaddress => self.ipaddress,
      :port      => self.port
    }
  end

  def username
    authentications.first.userid
  end

  def password
    authentications.first.password
  end

end
