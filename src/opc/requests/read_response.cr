
# https://reference.opcfoundation.org/v104/Core/DataTypes/ReadResponse/
class OPC::ReadResponse < BinData
  endian little

  custom response_header : ResponseHeader = ResponseHeader.new

  OPC.array results : DataValue
  OPC.array diagnostic_infos : DiagnosticInfo
end
