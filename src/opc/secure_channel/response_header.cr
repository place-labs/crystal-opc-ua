
# https://reference.opcfoundation.org/v104/Core/docs/Part4/7.29/
class OPC::ResponseHeader < BinData
  endian little

  uint64 timestamp
  uint32 request_handle

  # https://reference.opcfoundation.org/v104/Core/docs/Part4/7.34.1/
  uint32 service_result

  # https://reference.opcfoundation.org/v104/Core/docs/Part4/7.8/
  uint8 service_diagnostics

  int32 :string_table_size, value: ->{ OPC.store string_table.size }
  array string_table : GenericString, length: ->{ OPC.calculate string_table_size }

  custom additional_header : ExtensionObject = ExtensionObject.new
end
