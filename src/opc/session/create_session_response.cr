
module OPC
  # https://reference.opcfoundation.org/v104/Core/docs/Part4/5.6.2/
  class CreateSessionResponse < BinData
    endian little

    custom request_indicator : NodeID = NodeID.new(ObjectId[:create_session_response])
    custom response_header : ResponseHeader = ResponseHeader.new
    custom session_id : NodeID = NodeID.new
    custom authentication_token : NodeID = NodeID.new

    # Max idle duration in milliseconds
    float64 session_timeout

    OPC.bytes server_nonce
    OPC.bytes server_certificate
    OPC.array endpoints : EndPointDescription
    OPC.array deprecated_software_certificates : SignedSoftwareCertificate

    custom server_signature : SignatureData = SignatureData.new

    # The Server should return a Bad_ResponseTooLarge service fault if a response message exceeds this limit
    # The value zero indicates that this parameter is not used
    uint32 max_response_size
  end
end
