
# https://reference.opcfoundation.org/v104/Core/docs/Part3/8.3/
class OPC::QualifiedName < BinData
  endian little

  uint16 namespace_index
  OPC.string name
end
