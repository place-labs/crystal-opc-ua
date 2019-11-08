
class OPC::GetEndPointsResponse < BinData
  endian little

  custom response_header : ResponseHeader = ResponseHeader.new
  int32 :endpoints_size, value: ->{ OPC.store endpoints.size }
  array endpoints : EndPointDescription, length: ->{ OPC.calculate endpoints_size }
end
