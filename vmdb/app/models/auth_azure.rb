class AuthAzure < Authentication
  # Map userid to client_id, password to client_key and auth_key to tenant_id

  def client_id
    userid
  end

  def client_key
    password
  end

  def tenant_id
    auth_key
  end
end
