
class OPC::CloseSecureChannel < BinData
  endian little

  custom sequence_header : SequenceHeader = SequenceHeader.new
  custom request_indicator : NodeID = NodeID.new
  custom request_header : RequestHeader = RequestHeader.new
end
