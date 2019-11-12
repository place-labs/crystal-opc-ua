
module OPC
  # https://reference.opcfoundation.org/v104/Core/docs/Part4/5.6.3/
  class ActivateSessionRequest < BinData
    endian little

    POLICIES = {
      anonymous: {
        ObjectId[:anonymous_identity_token_encoding_default_binary],
        "crystalopc-anonymous-policy".to_slice
      },
      username: {
        ObjectId[:user_name_identity_token_encoding_default_binary],
        "crystalopc-username-policy".to_slice
      },
      x509: {
        ObjectId[:x509_identity_token_encoding_default_binary],
        "crystalopc-x509-policy".to_slice
      }
    }

    custom request_indicator : NodeID = NodeID.new(ObjectId[:activate_session_request_encoding_default_binary])
    custom request_header : RequestHeader = RequestHeader.new

    custom client_signature : SignatureData = SignatureData.new
    OPC.array client_software_certificates : SignedSoftwareCertificate
    OPC.array locale_ids : GenericString

    # Username + password etc
    # https://reference.opcfoundation.org/v104/Core/docs/Part4/7.36.1/
    custom user_identity : ExtensionObject = ExtensionObject.new
    custom user_token_signature : SignatureData = SignatureData.new
  end
end
