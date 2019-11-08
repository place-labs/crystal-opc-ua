
# https://reference.opcfoundation.org/v104/Core/docs/Part6/6.7.2/
class OPC::SequenceHeader < BinData
  endian little

  uint32 sequence_number
  uint32 request_id
end
