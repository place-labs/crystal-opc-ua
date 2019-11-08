
module OPC
  # TODO:: When parsing the security headers we need to peak the secure channel ID
  # so we can determine if we are using Symmetric or Asymmetric encryption
  #
  # https://reference.opcfoundation.org/v104/Core/docs/Part6/6.7.2/
  class AsymmetricSecurityHeader < BinData
    endian little

    uint32 :secure_channel_id

    # i.e. "http://opcfoundation.org/UA/SecurityPolicy#None"
    int32 :security_policy_uri_length, value: ->{ OPC.store security_policy_uri.bytesize }
    string :security_policy_uri, length: ->{ OPC.calculate security_policy_uri_length }

    int32 :sender_certificate_length, value: ->{ OPC.store sender_certificate.size }
    bytes :sender_certificate, length: ->{ OPC.calculate sender_certificate_length }
    int32 :receiver_certificate_thumbprint_length, value: ->{ OPC.store receiver_certificate_thumbprint.size }
    bytes :receiver_certificate_thumbprint, length: ->{ OPC.calculate receiver_certificate_thumbprint_length }
  end

  # https://reference.opcfoundation.org/v104/Core/docs/Part6/6.7.2/
  class SymmetricSecurityHeader < BinData
    endian little

    uint32 :secure_channel_id
    uint32 :token_id
  end
end
