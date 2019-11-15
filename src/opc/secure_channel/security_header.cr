
module OPC
  class BaseSecurityHeader < BinData
    endian little

    uint32 :secure_channel_id
  end

  # When parsing the security headers we need to peak the secure channel ID
  # so we can determine if we are using Symmetric or Asymmetric encryption
  #
  # https://reference.opcfoundation.org/v104/Core/docs/Part6/6.7.2/
  class AsymmetricSecurityHeader < BaseSecurityHeader
    endian little

    # i.e. "http://opcfoundation.org/UA/SecurityPolicy#None"
    OPC.string :security_policy_uri
    OPC.bytes :sender_certificate
    OPC.bytes :receiver_certificate_thumbprint
  end

  # https://reference.opcfoundation.org/v104/Core/docs/Part6/6.7.2/
  class SymmetricSecurityHeader < BaseSecurityHeader
    endian little

    uint32 :token_id
  end
end
