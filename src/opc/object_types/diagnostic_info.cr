
# https://reference.opcfoundation.org/v104/Core/docs/Part4/7.8/
class OPC::DiagnosticInfo < BinData
  endian little

  int32 namespace_uri_index
  int32 symbolic_id
  int32 locale
  int32 localized_text
  OPC.string additional_info
  uint32 inner_status_code
  # TODO:: inner_diagnostic_info
end
