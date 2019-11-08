
# https://reference.opcfoundation.org/v104/Core/DataTypes/EndpointDescription/
# https://reference.opcfoundation.org/v104/Core/docs/Part4/7.10/
class OPC::EndPointDescription < BinData
  endian little

  int32 :endpoint_url_size, value: ->{ OPC.store endpoint_url.bytesize }
  string :endpoint_url, length: ->{ OPC.calculate endpoint_url_size }

  custom server : ApplicationDescription = ApplicationDescription.new

  int32 :server_certificate_size, value: ->{ OPC.store server_certificate.size }
  bytes :server_certificate, length: ->{ OPC.calculate server_certificate_size }

  enum_field UInt32, security_mode : MessageSecurityMode = MessageSecurityMode::NoSecurity
  int32 :security_policy_uri_length, value: ->{ OPC.store security_policy_uri.bytesize }
  string :security_policy_uri, length: ->{ OPC.calculate security_policy_uri_length }

  int32 :user_identity_tokens_size, value: ->{ OPC.store user_identity_tokens.size }
  array user_identity_tokens : UserTokenPolicy, length: ->{ OPC.calculate user_identity_tokens_size }

  int32 :transport_profile_uri_length, value: ->{ OPC.store transport_profile_uri.bytesize }
  string :transport_profile_uri, length: ->{ OPC.calculate transport_profile_uri_length }

  # Just here so you can sort on security level (higher is better)
  uint8 :security_level
end
