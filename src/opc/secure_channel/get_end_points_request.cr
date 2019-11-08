
class OPC::GetEndPointsRequest < BinData
  endian little

  DEFAULT_LOCALE_ID = GenericString.new
  DEFAULT_LOCALE_ID.value = "http://opcfoundation.org/UA-Profile/Transport/uatcp-uasc-uabinary"

  DEFAULT_PROFILE_URI = GenericString.new
  DEFAULT_PROFILE_URI.value = "http://opcfoundation.org/UA-Profile/Transport/uatcp-uasc-uabinary"

  # This is typically not part of the request - but this will never be encrpyted
  custom security_header : SymmetricSecurityHeader = SymmetricSecurityHeader.new

  custom sequence_header : SequenceHeader = SequenceHeader.new
  custom request_indicator : NodeID = NodeID.new
  custom request_header : RequestHeader = RequestHeader.new

  int32 :endpoint_url_size, value: ->{ OPC.store endpoint_url.bytesize }
  string :endpoint_url, length: ->{ OPC.calculate endpoint_url_size }

  int32 :locale_ids_size, value: ->{ OPC.store locale_ids.size }
  array locale_ids : GenericString, length: ->{ OPC.calculate locale_ids_size }

  int32 :profile_uris_size, value: ->{ OPC.store profile_uris.size }
  array profile_uris : GenericString, length: ->{ OPC.calculate profile_uris_size }
end
