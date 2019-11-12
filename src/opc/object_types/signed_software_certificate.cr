
# https://reference.opcfoundation.org/v104/Core/docs/Part4/7.33/
class OPC::SignedSoftwareCertificate < BinData
  endian little

  OPC.bytes certificate_data
  OPC.bytes signature
end
