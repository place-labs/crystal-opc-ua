
# https://reference.opcfoundation.org/v104/Core/DataTypes/EndpointDescription/
# https://reference.opcfoundation.org/v104/Core/docs/Part4/7.10/
class OPC::EndPointDescription < BinData
  endian little

  OPC.string :endpoint_url

  custom server : ApplicationDescription = ApplicationDescription.new

  OPC.bytes :server_certificate

  enum_field UInt32, security_mode : MessageSecurityMode = MessageSecurityMode::NoSecurity
  OPC.string :security_policy_uri

  int32 :user_identity_tokens_size, value: ->{ OPC.store user_identity_tokens.size }
  array user_identity_tokens : UserTokenPolicy, length: ->{ OPC.calculate user_identity_tokens_size }

  OPC.string :transport_profile_uri

  # Just here so you can sort on security level (higher is better)
  uint8 :security_level
end
