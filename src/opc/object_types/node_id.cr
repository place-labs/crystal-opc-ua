
module OPC
  enum TypeOfNodeID
    TwoByte  # Single byte of data
    FourByte # 16bits of data
    Numeric  # 32bits of data
    String
    GUID
    ByteString
    NamespaceUriFlag = 0x80
    ServerIndexFlag  = 0x40
  end

  # https://reference.opcfoundation.org/v104/Core/docs/Part6/5.2.2/#Table5
  class NodeID < BinData
    endian little

    enum_field UInt8, node_type : TypeOfNodeID = TypeOfNodeID::TwoByte

    # if node_type == 0
    uint8 :two_byte_data, onlyif: ->{ node_type == TypeOfNodeID::TwoByte }

    # if node_type == 1
    uint8 :namespace_byte, onlyif: ->{ node_type == TypeOfNodeID::FourByte }
    uint16 :four_byte_data, onlyif: ->{ node_type == TypeOfNodeID::FourByte }

    # if node_type >= 2
    uint16 :namespace, onlyif: ->{ node_type.to_i > 1 }

    # Numeric
    uint32 :numeric_data, onlyif: ->{ node_type == TypeOfNodeID::Numeric }

    # String
    int32 :string_data_size, value: ->{ OPC.store string_data.bytesize }, onlyif: ->{ node_type == TypeOfNodeID::String }
    string :string_data, length: ->{ OPC.calculate string_data_size }, onlyif: ->{ node_type == TypeOfNodeID::String }

    # Byte string
    uint32 :byte_string_data_size, value: ->{ OPC.store byte_string_data.bytesize }, onlyif: ->{ node_type == TypeOfNodeID::ByteString }
    bytes :byte_string_data, length: ->{ OPC.calculate byte_string_data_size }, onlyif: ->{ node_type == TypeOfNodeID::ByteString }
  end
end
