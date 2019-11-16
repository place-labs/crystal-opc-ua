
module OPC
  # https://reference.opcfoundation.org/v104/Core/docs/Part4/5.6.3/
  class ActivateSessionResponse < BinData
    endian little

    # custom response_indicator : NodeID = NodeID.new(ObjectId[:activate_session_request_encoding_default_binary])
    # custom response_header : ResponseHeader = ResponseHeader.new

    OPC.bytes server_nonce

    # List of validation results for the SoftwareCertificates
    # https://reference.opcfoundation.org/v104/Core/docs/Part4/7.34.1/
    OPC.array results : UInt32

    # https://reference.opcfoundation.org/v104/Core/docs/Part4/7.8
    OPC.array diagnostic_infos : DiagnosticInfo
  end
end
