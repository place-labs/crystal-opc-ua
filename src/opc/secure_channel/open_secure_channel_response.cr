
class OPC::OpenSecureChannelResponse < BinData
  endian little

  # custom security_header : AsymmetricSecurityHeader = AsymmetricSecurityHeader.new

  # Data that can be encrypted:
  # ==========================
  # custom sequence_header : SequenceHeader = SequenceHeader.new
  # custom request_indicator : NodeID = NodeID.new
  custom response_header : ResponseHeader = ResponseHeader.new
  uint32 :protocol_version
  custom security_token : ChannelSecurityToken = ChannelSecurityToken.new
end
