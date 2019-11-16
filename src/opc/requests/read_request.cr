
module OPC
  enum TimestampsToReturn
    Source
    Server
    Both
    Neither
    Invalid
  end

  # https://reference.opcfoundation.org/v104/Core/DataTypes/ReadValueId/
  class ReadValueId < BinData
    endian little

    def self.new(node, attribute)
      read = ReadValueId.new
      read.node_id.value = node
      read.attribute_id = attribute
      read
    end

    custom node_id : NodeID = NodeID.new
    uint32 attribute_id

    # https://reference.opcfoundation.org/v104/Core/docs/Part4/7.22/
    # examples: (All indexes start with 0)
    # * "6" => [6]
    # * "5:7" => [5, 6]
    # * "1:3,0:2" => [1[0, 1], 2[0, 1]]
    OPC.string index_range
    custom data_encoding : QualifiedName = QualifiedName.new
  end

  # https://reference.opcfoundation.org/v104/Core/DataTypes/ReadRequest/
  class ReadRequest < BinData
    endian little

    custom request_indicator : NodeID = NodeID.new(ObjectId[:read_request_encoding_default_binary])
    custom request_header : RequestHeader = RequestHeader.new

    uint64 max_age
    enum_field UInt32, request_type : TimestampsToReturn = TimestampsToReturn::Both

    OPC.array nodes_to_read : ReadValueId
  end
end
