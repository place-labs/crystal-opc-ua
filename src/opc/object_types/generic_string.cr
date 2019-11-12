
class OPC::GenericString < BinData
  endian little

  def self.new(string : String)
    instance = GenericString.new
    instance.value = string
    instance
  end

  OPC.string :value
end
