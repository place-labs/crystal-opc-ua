
# https://reference.opcfoundation.org/v104/Core/docs/Part6/5.2.2/#5.2.2.1
class OPC::Boolean < BinData
  endian little

  uint8 data

  def value : Bool
    data > 0
  end

  def value=(state : Bool)
    data = state ? 1_u8 : 0_u8
  end
end
