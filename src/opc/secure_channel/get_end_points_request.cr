
class OPC::GetEndPointsRequest < BinData
  endian little

  DEFAULT_LOCALE_ID = GenericString.new
  DEFAULT_LOCALE_ID.value = "http://opcfoundation.org/UA-Profile/Transport/uatcp-uasc-uabinary"

  DEFAULT_PROFILE_URI = GenericString.new
  DEFAULT_PROFILE_URI.value = "http://opcfoundation.org/UA-Profile/Transport/uatcp-uasc-uabinary"

  custom request_indicator : NodeID = NodeID.new(ObjectId[:get_endpoints_request_encoding_default_binary])
  custom request_header : RequestHeader = RequestHeader.new

  OPC.string :endpoint_url
  OPC.array locale_ids : GenericString
  OPC.array profile_uris : GenericString
end
