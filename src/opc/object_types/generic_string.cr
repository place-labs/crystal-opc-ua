
class OPC::GenericString < BinData
  endian little

  int32 :value_size, value: ->{ OPC.store value.bytesize }
  string :value, length: ->{ OPC.calculate value_size }
end
