require "socket"
require "bindata"
require "tokenizer"

# https://reference.opcfoundation.org/v104/Core/docs/Part6/7.1.2/
# https://reference.opcfoundation.org/v104/Core/docs/Part6/6.7.2/#Table41
# Error codes: https://python-opcua.readthedocs.io/en/latest/_modules/opcua/ua/status_codes.html#StatusCodes

module OPC
  def self.store(size)
    size == 0 ? -1 : size
  end

  def self.calculate(size)
    size < 0 ? 0 : size
  end

  # https://github.com/open62541/open62541/blob/9f0c73d6ea3388f858891323f84cb9e321b4a3fb/include/open62541/types.h#L236
  # 10_000_000 == 1 second in 100 nanosecond intervals
  UA_DATETIME_SEC =         10_000_000_u64
  UA_UNIX_EPOCH   = 116444736000000000_u64

  def self.ua_datetime_to_time(time : UInt64) : Time
    Time.from_unix((time - UA_UNIX_EPOCH) / UA_DATETIME_SEC)
  end

  def self.time_to_ua_datetime(time : Time) : UInt64
    (time.to_unix.to_u64 * UA_DATETIME_SEC) + UA_UNIX_EPOCH
  end

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

  # =====================
  # Base protocol classes
  # =====================

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
    int32 :endpoint_url_size, value: ->{ OPC.store endpoint_url.bytesize }
    string :endpoint_url, length: ->{ OPC.calculate endpoint_url_size }
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
    int32 :reason_size, value: ->{ OPC.store reason.bytesize }
    string :reason, length: ->{ OPC.calculate reason_size }
  end

  # ReverseHello represents a OPC UA ReverseHello.
  #
  # Specification: Part6, 7.1.2.6
  class ReverseHelloMessage < BinData
    endian little

    int32 :server_uri_size, value: ->{ OPC.store server_uri.bytesize }
    string :server_uri, length: ->{ OPC.calculate server_uri_size }

    int32 :endpoint_url_size, value: ->{ OPC.store endpoint_url.bytesize }
    string :endpoint_url, length: ->{ OPC.calculate endpoint_url_size }
  end

  # ======================
  # Secure Channel Classes
  # ======================

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

  # https://reference.opcfoundation.org/v104/Core/docs/Part6/5.2.2/#Table14
  enum BodyEncoding
    NoBody
    ByteString
    XmlElement
  end

  # https://reference.opcfoundation.org/v104/Core/docs/Part6/5.2.2/#Table14
  class ExtensionObject < BinData
    endian little

    custom type_id : NodeID = NodeID.new
    enum_field UInt8, encoding : BodyEncoding = BodyEncoding::NoBody

    int32 :length, value: ->{ OPC.store(encoding == BodyEncoding::ByteString ? byte_data.size : xml_data.bytesize) }, onlyif: ->{ encoding != BodyEncoding::NoBody }
    bytes :byte_data, length: ->{ OPC.calculate length }, onlyif: ->{ encoding == BodyEncoding::ByteString }
    string :xml_data, length: ->{ OPC.calculate length }, onlyif: ->{ encoding == BodyEncoding::XmlElement }
  end

  class RequestHeader < BinData
    endian little

    custom authentication_token : NodeID = NodeID.new
    # A DateTime value shall be encoded as a 64-bit signed integer
    # (see Clause 5.2.2.2) which represents the
    # number of 100 nanosecond intervals since January 1, 1601 (UTC).
    # 10_000_000 == 1 second in 100 nanosecond intervals
    # unix * 10_000_000 + 116444736000000000 == timestamp
    uint64 timestamp, value: ->{ OPC.time_to_ua_datetime(Time.utc) }
    uint32 request_handle, default: 1
    uint32 return_diagnostics

    # For tracking requests through different systems
    int32 :audit_entry_id_size, value: ->{ OPC.store audit_entry_id.bytesize }
    string :audit_entry_id, length: ->{ OPC.calculate audit_entry_id_size }

    # How long the client is willing to wait for a response (optional)
    uint32 :timeout_hint
    custom additional_header : ExtensionObject = ExtensionObject.new
  end

  # https://reference.opcfoundation.org/v104/Core/docs/Part6/6.7.2/
  class AsymmetricSecurityHeader < BinData
    endian little

    uint32 :secure_channel_id

    # i.e. "http://opcfoundation.org/UA/SecurityPolicy#None"
    int32 :security_policy_uri_length, value: ->{ OPC.store security_policy_uri.bytesize }
    string :security_policy_uri, length: ->{ OPC.calculate security_policy_uri_length }

    uint32 :sender_certificate_length, value: ->{ OPC.store sender_certificate.size }
    bytes :sender_certificate, length: ->{ OPC.calculate sender_certificate_length }
    uint32 :receiver_certificate_thumbprint_length, value: ->{ OPC.store receiver_certificate_thumbprint.size }
    bytes :receiver_certificate_thumbprint, length: ->{ OPC.calculate receiver_certificate_thumbprint_length }
  end

  # https://reference.opcfoundation.org/v104/Core/docs/Part6/6.7.2/
  class SymmetricSecurityHeader < BinData
    endian little

    uint32 :secure_channel_id
    uint32 :token_id
  end

  # https://reference.opcfoundation.org/v104/Core/docs/Part6/6.7.2/
  class SequenceHeader < BinData
    endian little

    uint32 sequence_number
    uint32 request_id
  end

  enum SecurityTokenRequestType
    Issue
    Renew
  end

  enum MessageSecurityMode
    NoSecurity     = 1
    Sign
    SignAndEncrypt
  end

  class OpenSecureChannelMessage < BinData
    endian little

    custom security_header : AsymmetricSecurityHeader = AsymmetricSecurityHeader.new
    custom sequence_header : SequenceHeader = SequenceHeader.new

    custom request_indicator : NodeID = NodeID.new
    custom request_header : RequestHeader = RequestHeader.new

    uint32 :protocol_version
    enum_field UInt32, request_type : SecurityTokenRequestType = SecurityTokenRequestType::Issue
    enum_field UInt32, security_mode : MessageSecurityMode = MessageSecurityMode::NoSecurity

    uint32 :client_nonce_size, value: ->{ OPC.store client_nonce.size }
    bytes :client_nonce, length: ->{ OPC.calculate client_nonce_size }

    # Milliseconds to keep the channel alive
    uint32 :requested_lifetime
  end

  # =========================
  # Response related classes:
  # =========================

  # https://reference.opcfoundation.org/v104/Core/docs/Part4/7.29/
  class ResponseHeader < BinData
    endian little

    uint64 timestamp
    uint32 request_handle

    # https://reference.opcfoundation.org/v104/Core/docs/Part4/7.34.1/
    uint32 service_result

    # https://reference.opcfoundation.org/v104/Core/docs/Part4/7.8/
    uint8 service_diagnostics



  end

  class OpenSecureChannelResponse < BinData
    endian little

    custom security_header : AsymmetricSecurityHeader = AsymmetricSecurityHeader.new
    custom sequence_header : SequenceHeader = SequenceHeader.new

    custom request_indicator : NodeID = NodeID.new
    custom request_header : RequestHeader = RequestHeader.new

    uint32 :protocol_version
    enum_field UInt32, request_type : SecurityTokenRequestType = SecurityTokenRequestType::Issue
    enum_field UInt32, security_mode : MessageSecurityMode = MessageSecurityMode::NoSecurity

    uint32 :client_nonce_size, value: ->{ OPC.store client_nonce.size }
    bytes :client_nonce, length: ->{ OPC.calculate client_nonce_size }

    # Milliseconds to keep the channel alive
    uint32 :requested_lifetime
  end

  # https://reference.opcfoundation.org/v104/Core/docs/Part6/6.7.2/
  # class MessageFooter
  # TODO:: involves encryption
  # end

  module Default
    KB = 1024_u32
    MB = 1024_u32 * KB

    ReceiveBufSize = 0xffff_u32
    SendBufSize    = 0xffff_u32
    MaxChunkCount  =    512_u32
    MaxMessageSize = 2_u32 * MB
  end

  # Message parser
  class UA
    def initialize
      @buffer = Tokenizer.new do |io|
        if io.size >= 8
          header = io.read_bytes(MessageHeader)
          header.size.to_i
        else
          -1
        end
      end
      @parts = [] of Bytes
    end

    def clear_buffer
      @buffer.clear
      @parts = [] of Bytes
    end

    def extract(data)
      @buffer.extract(data).each do |message|
        if message.is_final?
          begin
            if @parts.size > 0
              @parts << message
              parts = @parts
              @parts = [] of Bytes
              yield parts
            else
              yield message
            end
          rescue e
            # TODO:: log error
          end
        else
          @parts << message
        end
      end
    end

    def hello(endpoint_url)
      msg = HelloMessage.new
      msg.protocol_version = 0_u32
      msg.receive_buffer_size = Default::ReceiveBufSize
      msg.send_buffer_size = Default::SendBufSize
      msg.max_message_size = Default::MaxMessageSize
      msg.max_chunk_count = Default::MaxChunkCount
      msg.endpoint_url = endpoint_url.to_s

      msg_bytes = msg.to_slice

      header = MessageHeader.new
      header.message_type = MESSAGE_TYPE[:hello]
      header.chunk_indicator = CHUNK_TYPE[:final]
      header.size = (msg_bytes.size + 8).to_u32

      {header.to_slice, msg_bytes}
    end

    def open_channel
      secure = OpenSecureChannelMessage.new
      secure.security_mode = MessageSecurityMode::NoSecurity
      secure.requested_lifetime = 1.hour.total_milliseconds.to_u32
      secure.sequence_header.sequence_number = 1
      secure.sequence_header.request_id = 1
      secure.request_indicator.node_type = TypeOfNodeID::FourByte
      secure.request_indicator.four_byte_data = 446
      secure.security_header.security_policy_uri = "http://opcfoundation.org/UA/SecurityPolicy#None"
      msg_bytes = secure.to_slice

      header = MessageHeader.new
      header.message_type = MESSAGE_TYPE[:open_secure_channel]
      header.chunk_indicator = CHUNK_TYPE[:final]
      header.size = (msg_bytes.size + 8).to_u32

      {header.to_slice, msg_bytes}
    end

    # An example of basic protocol negotiation
    def connect_to(server, port, connection_string)
      client = TCPSocket.new(server, port)
      client.sync = false

      begin
        # Say Hello
        header, msg = hello(connection_string)

        client.write header
        client.write msg
        client.flush

        header = client.read_bytes OPC::MessageHeader
        case header.message_type
        when "ACK"
          client.read_bytes OPC::AcknowledgeMessage
        when "ERR"
          client.read_bytes OPC::ErrorMessage
        else
          raw_data = Bytes.new(2048)
          bytes_read = client.read raw_data
          data = raw_data[0, bytes_read]
          raise data.to_s
        end

        # Init a secure channel
        header, msg = open_channel
        client.write header
        client.write msg
        client.flush

        header = client.read_bytes OPC::MessageHeader
        case header.message_type
        when "ACK"
          client.read_bytes OPC::AcknowledgeMessage
        when "ERR"
          client.read_bytes OPC::ErrorMessage
        else
          # TODO:: parse the open secure channel response
          raw_data = Bytes.new(2048)
          bytes_read = client.read raw_data
          data = raw_data[0, bytes_read]
        end
      ensure
        client.close
      end
    end
  end
end

require "./opc/*"
