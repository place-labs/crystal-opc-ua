
module OPC
  enum SecurityTokenRequestType
    Issue
    Renew
  end

  # https://reference.opcfoundation.org/v104/Core/docs/Part4/7.15/
  enum MessageSecurityMode
    NoSecurity     = 1
    Sign
    SignAndEncrypt
  end

  class OpenSecureChannelRequest < BinData
    endian little

    custom request_indicator : NodeID = NodeID.new(ObjectId[:open_secure_channel_request_encoding_default_binary])
    custom request_header : RequestHeader = RequestHeader.new

    uint32 :protocol_version
    enum_field UInt32, request_type : SecurityTokenRequestType = SecurityTokenRequestType::Issue
    enum_field UInt32, security_mode : MessageSecurityMode = MessageSecurityMode::NoSecurity

    OPC.bytes :client_nonce

    # Milliseconds to keep the channel alive
    uint32 :requested_lifetime
  end
end
