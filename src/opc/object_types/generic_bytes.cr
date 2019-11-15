
class OPC::GenericBytes < BinData
  endian little

  def self.new(bytes : Bytes)
    instance = GenericBytes.new
    instance.value = bytes
    instance
  end

  OPC.bytes :value
end
