
module OPC
  # MessageType definitions.
  #
  # Specification: Part 6, 7.1.2.2
  MESSAGE_TYPE = {
    # Base protocol
    hello:         "HEL",
    acknowledge:   "ACK",
    error:         "ERR",
    reverse_hello: "RHE",

    # Those implemented by SecureChannel
    message:              "MSG",
    open_secure_channel:  "OPN",
    close_secure_channel: "CLO",
  }

  # ChunkType definitions.
  #
  # Specification: Part 6, 6.7.2.2
  CHUNK_TYPE = {
    intermediate: "C",
    final:        "F",
    abort:        "A",
  }

  # Header represents a OPC UA Connection Header.
  #
  # Specification: Part 6, 7.1.2.2
  # https://reference.opcfoundation.org/v104/Core/docs/Part6/6.7.2/
  class MessageHeader < BinData
    endian little

    string :message_type, length: ->{ 3 }

    # F == final / complete message
    # C == intermediate chunk / more to follow
    # A == abort
    string :chunk_indicator, length: ->{ 1 }
    uint32 :size

    def is_final?
      chunk_indicator == "F"
    end
  end

  # Hello represents a OPC UA Hello.
  #
  # Specification: Part6, 7.1.2.3
  class HelloMessage < BinData
    endian little

    uint32 :protocol_version
    uint32 :receive_buffer_size
    uint32 :send_buffer_size
    uint32 :max_message_size
    uint32 :max_chunk_count
    OPC.string :endpoint_url
  end

  # Acknowledge represents a OPC UA Acknowledge.
  #
  # Specification: Part6, 7.1.2.4
  class AcknowledgeMessage < BinData
    endian little

    uint32 :protocol_version
    uint32 :receive_buffer_size
    uint32 :send_buffer_size
    uint32 :max_message_size
    uint32 :max_chunk_count
  end

  # Error represents a OPC UA Error.
  #
  # Specification: Part6, 7.1.2.5
  # Base10 error codes: https://python-opcua.readthedocs.io/en/latest/opcua.ua.html#opcua.ua.status_codes.StatusCodes.BadTcpMessageTypeInvalid
  # Error descriptions: https://python-opcua.readthedocs.io/en/latest/_modules/opcua/ua/status_codes.html#StatusCodes
  class ErrorMessage < BinData
    endian little

    uint32 :code
    OPC.string :reason
  end

  # ReverseHello represents a OPC UA ReverseHello.
  #
  # Specification: Part6, 7.1.2.6
  class ReverseHelloMessage < BinData
    endian little

    OPC.string :server_uri
    OPC.string :endpoint_url
  end
end
