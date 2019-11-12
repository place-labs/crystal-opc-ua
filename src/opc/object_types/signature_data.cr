
# https://reference.opcfoundation.org/v104/Core/docs/Part4/7.33/
class OPC::SignatureData < BinData
  endian little

  OPC.string algorithm_uri
  OPC.bytes signature
end
