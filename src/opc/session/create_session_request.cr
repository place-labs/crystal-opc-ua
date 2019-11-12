
module OPC
  # https://reference.opcfoundation.org/v104/Core/docs/Part4/5.6.2/
  class CreateSessionRequest < BinData
    endian little

    custom request_indicator : NodeID = NodeID.new(ObjectId[:create_session_request_encoding_default_binary])
    custom request_header : RequestHeader = RequestHeader.new

    custom client_description : ApplicationDescription = ApplicationDescription.new

    OPC.string server_uri
    OPC.string endpoint_url
    OPC.string session_name
    OPC.bytes client_nonce

    # TODO:: we should parse the client certificate bytes (ApplicationInstanceCertificate)
    OPC.bytes client_certificate

    # Max idle duration in milliseconds
    float64 session_timeout

    # The Server should return a Bad_ResponseTooLarge service fault if a response message exceeds this limit
    # The value zero indicates that this parameter is not used
    uint32 max_response_size
  end
end
