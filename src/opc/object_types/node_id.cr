
module OPC
  enum TypeOfNodeID
    TwoByte  # Single byte of data
    FourByte # 16bits of data
    Numeric  # 32bits of data
    String
    GUID
    ByteString
  end

  @[Flags]
  enum NodeIDFlags
    ServerIndexFlag
    NamespaceUriFlag
  end

  # https://reference.opcfoundation.org/v104/Core/docs/Part6/5.2.2/#Table5
  class NodeID < BinData
    endian little

    def self.new(value)
      node = NodeID.new
      node.value = value
      node
    end

    def value=(data)
      if data.is_a?(UInt8)
        self.node_type = TypeOfNodeID::TwoByte
        @two_byte_data = data
      end

      if data.is_a?(UInt16)
        self.node_type = TypeOfNodeID::FourByte
        @four_byte_data = data
      end

      if data.is_a?(UInt32)
        self.node_type = TypeOfNodeID::Numeric
        @numeric_data = data
      end

      if data.is_a?(UInt128)
        self.node_type = TypeOfNodeID::GUID
        @numeric_data = data
      end

      if data.is_a?(String)
        self.node_type = TypeOfNodeID::String
        @string_data = data
      end

      if data.is_a?(Bytes)
        self.node_type = TypeOfNodeID::ByteString
        @byte_string_data = data
      end

      data
    end

    bit_field do
      enum_bits 2, flags : NodeIDFlags = NodeIDFlags::None
      enum_bits 6, node_type : TypeOfNodeID = TypeOfNodeID::TwoByte
    end

    # if node_type == 0
    uint8 :two_byte_data, onlyif: ->{ node_type == TypeOfNodeID::TwoByte }

    # if node_type == 1
    uint8 :namespace_byte, onlyif: ->{ node_type == TypeOfNodeID::FourByte }
    uint16 :four_byte_data, onlyif: ->{ node_type == TypeOfNodeID::FourByte }

    # if node_type >= 2
    uint16 :namespace, onlyif: ->{ node_type.to_i > 1 }

    # Numeric
    uint32 :numeric_data, onlyif: ->{ node_type == TypeOfNodeID::Numeric }

    # GUID
    uint128 :guid, onlyif: ->{ node_type == TypeOfNodeID::GUID }

    # String
    int32 :string_data_size, value: ->{ OPC.store string_data.bytesize }, onlyif: ->{ node_type == TypeOfNodeID::String }
    string :string_data, length: ->{ OPC.calculate string_data_size }, onlyif: ->{ node_type == TypeOfNodeID::String }

    # Byte string
    uint32 :byte_string_data_size, value: ->{ OPC.store byte_string_data.bytesize }, onlyif: ->{ node_type == TypeOfNodeID::ByteString }
    bytes :byte_string_data, length: ->{ OPC.calculate byte_string_data_size }, onlyif: ->{ node_type == TypeOfNodeID::ByteString }
  end
end
