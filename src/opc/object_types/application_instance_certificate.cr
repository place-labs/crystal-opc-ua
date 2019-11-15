
# https://reference.opcfoundation.org/v104/Core/docs/Part4/7.2/
class OPC::ApplicationInstanceCertificate < BinData
  endian little

  OPC.string :version
  OPC.bytes :serial_number
  OPC.string :signature_algorithm
  OPC.bytes :signature
  # TODO:: issuer (Structure)
  uint64 :valid_from
  uint64 :valid_to
  # TODO:: subject (Structure)
  OPC.string :application_uri
  OPC.array hostnames : GenericString
  OPC.bytes :public_key
  OPC.array key_usage : GenericString
end
