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

  # TODO:: When parsing the security headers we need to peak the secure channel ID
  # so we can determine if we are using Symmetric or Asymmetric encryption
  #
  # https://reference.opcfoundation.org/v104/Core/docs/Part6/6.7.2/
  class AsymmetricSecurityHeader < BinData
    endian little

    uint32 :secure_channel_id

    # i.e. "http://opcfoundation.org/UA/SecurityPolicy#None"
    int32 :security_policy_uri_length, value: ->{ OPC.store security_policy_uri.bytesize }
    string :security_policy_uri, length: ->{ OPC.calculate security_policy_uri_length }

    int32 :sender_certificate_length, value: ->{ OPC.store sender_certificate.size }
    bytes :sender_certificate, length: ->{ OPC.calculate sender_certificate_length }
    int32 :receiver_certificate_thumbprint_length, value: ->{ OPC.store receiver_certificate_thumbprint.size }
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

  # https://reference.opcfoundation.org/v104/Core/docs/Part4/7.15/
  enum MessageSecurityMode
    NoSecurity     = 1
    Sign
    SignAndEncrypt
  end

  class OpenSecureChannelMessage < BinData
    endian little

    custom security_header : AsymmetricSecurityHeader = AsymmetricSecurityHeader.new

    # Data that can be encrypted:
    custom sequence_header : SequenceHeader = SequenceHeader.new
    custom request_indicator : NodeID = NodeID.new
    custom request_header : RequestHeader = RequestHeader.new

    uint32 :protocol_version
    enum_field UInt32, request_type : SecurityTokenRequestType = SecurityTokenRequestType::Issue
    enum_field UInt32, security_mode : MessageSecurityMode = MessageSecurityMode::NoSecurity

    int32 :client_nonce_size, value: ->{ OPC.store client_nonce.size }
    bytes :client_nonce, length: ->{ OPC.calculate client_nonce_size }

    # Milliseconds to keep the channel alive
    uint32 :requested_lifetime
  end

  # =========================
  # Response related classes:
  # =========================

  class GenericString < BinData
    endian little

    int32 :value_size, value: ->{ OPC.store value.bytesize }
    string :value, length: ->{ OPC.calculate value_size }
  end

  # https://reference.opcfoundation.org/v104/Core/docs/Part4/7.29/
  class ResponseHeader < BinData
    endian little

    uint64 timestamp
    uint32 request_handle

    # https://reference.opcfoundation.org/v104/Core/docs/Part4/7.34.1/
    uint32 service_result

    # https://reference.opcfoundation.org/v104/Core/docs/Part4/7.8/
    uint8 service_diagnostics

    int32 :string_table_size, value: ->{ OPC.store string_table.size }
    array string_table : GenericString, length: ->{ OPC.calculate string_table_size }

    custom additional_header : ExtensionObject = ExtensionObject.new
  end

  class ChannelSecurityToken < BinData
    endian little

    uint32 :channel_id
    uint32 :token_id
    uint64 :timestamp
    uint32 :revised_lifetime

    int32 :server_nonce_size, value: ->{ OPC.store server_nonce.size }
    bytes :server_nonce, length: ->{ OPC.calculate server_nonce_size }

    def created_at
      OPC.ua_datetime_to_time timestamp
    end
  end

  class OpenSecureChannelResponse < BinData
    endian little

    # custom security_header : AsymmetricSecurityHeader = AsymmetricSecurityHeader.new

    # Data that can be encrypted:
    # ==========================
    # custom sequence_header : SequenceHeader = SequenceHeader.new
    # custom request_indicator : NodeID = NodeID.new
    custom response_header : ResponseHeader = ResponseHeader.new
    uint32 :protocol_version
    custom security_token : ChannelSecurityToken = ChannelSecurityToken.new
  end

  class GetEndPointsRequest < BinData
    endian little

    DEFAULT_LOCALE_ID = GenericString.new
    DEFAULT_LOCALE_ID.value = "http://opcfoundation.org/UA-Profile/Transport/uatcp-uasc-uabinary"

    DEFAULT_PROFILE_URI = GenericString.new
    DEFAULT_PROFILE_URI.value = "http://opcfoundation.org/UA-Profile/Transport/uatcp-uasc-uabinary"

    # This is typically not part of the request - but this will never be encrpyted
    custom security_header : SymmetricSecurityHeader = SymmetricSecurityHeader.new

    custom sequence_header : SequenceHeader = SequenceHeader.new
    custom request_indicator : NodeID = NodeID.new
    custom request_header : RequestHeader = RequestHeader.new

    int32 :endpoint_url_size, value: ->{ OPC.store endpoint_url.bytesize }
    string :endpoint_url, length: ->{ OPC.calculate endpoint_url_size }

    int32 :locale_ids_size, value: ->{ OPC.store locale_ids.size }
    array locale_ids : GenericString, length: ->{ OPC.calculate locale_ids_size }

    int32 :profile_uris_size, value: ->{ OPC.store profile_uris.size }
    array profile_uris : GenericString, length: ->{ OPC.calculate profile_uris_size }
  end

  # https://reference.opcfoundation.org/v104/Core/DataTypes/ApplicationType/
  enum ApplicationType
    Server
    Client
    ClientAndServer
    DiscoveryServer
  end

  # https://reference.opcfoundation.org/v104/Core/docs/Part6/5.2.2/#Table13
  @[Flags]
  enum LocalizedTextFlags
    Locale # 1
    Text   # 2
  end

  # https://reference.opcfoundation.org/v104/Core/docs/Part6/5.2.2/#Table13
  class LocalizedText < BinData
    endian little

    enum_field UInt8, mask : LocalizedTextFlags = LocalizedTextFlags::None

    int32 :locale_size, value: ->{ OPC.store locale.bytesize }, onlyif: ->{ mask.locale? }
    string :locale, length: ->{ OPC.calculate locale_size }, onlyif: ->{ mask.locale? }

    int32 :text_size, value: ->{ OPC.store text.bytesize }, onlyif: ->{ mask.text? }
    string :text, length: ->{ OPC.calculate text_size }, onlyif: ->{ mask.text? }
  end

  # https://reference.opcfoundation.org/v104/Core/DataTypes/ApplicationDescription/
  class ApplicationDescription < BinData
    endian little

    int32 :application_url_size, value: ->{ OPC.store application_url.bytesize }
    string :application_url, length: ->{ OPC.calculate application_url_size }

    int32 :product_url_size, value: ->{ OPC.store product_url.bytesize }
    string :product_url, length: ->{ OPC.calculate product_url_size }

    custom application_name : LocalizedText = LocalizedText.new
    enum_field UInt32, application_type : ApplicationType = ApplicationType::Client

    int32 :gateway_server_uri_size, value: ->{ OPC.store gateway_server_uri.bytesize }
    string :gateway_server_uri, length: ->{ OPC.calculate gateway_server_uri_size }

    int32 :discovery_profile_uri_size, value: ->{ OPC.store discovery_profile_uri.bytesize }
    string :discovery_profile_uri, length: ->{ OPC.calculate discovery_profile_uri_size }

    int32 :disovery_urls_size, value: ->{ OPC.store disovery_urls.size }
    array disovery_urls : GenericString, length: ->{ OPC.calculate disovery_urls_size }
  end

  # https://reference.opcfoundation.org/v104/Core/DataTypes/UserTokenType/
  enum UserTokenType
    Anonymous
    UserName
    Certificate
    IssuedToken
  end

  # https://reference.opcfoundation.org/v104/Core/DataTypes/UserTokenPolicy/
  class UserTokenPolicy < BinData
    endian little

    int32 :gateway_server_uri_size, value: ->{ OPC.store gateway_server_uri.bytesize }
    string :gateway_server_uri, length: ->{ OPC.calculate gateway_server_uri_size }

    enum_field UInt32, token_type : UserTokenType = UserTokenType::Anonymous

    int32 :gateway_server_uri_size, value: ->{ OPC.store gateway_server_uri.bytesize }
    string :gateway_server_uri, length: ->{ OPC.calculate gateway_server_uri_size }

    int32 :gateway_server_uri_size, value: ->{ OPC.store gateway_server_uri.bytesize }
    string :gateway_server_uri, length: ->{ OPC.calculate gateway_server_uri_size }

    int32 :gateway_server_uri_size, value: ->{ OPC.store gateway_server_uri.bytesize }
    string :gateway_server_uri, length: ->{ OPC.calculate gateway_server_uri_size }
  end

  # https://reference.opcfoundation.org/v104/Core/DataTypes/EndpointDescription/
  # https://reference.opcfoundation.org/v104/Core/docs/Part4/7.10/
  class EndPointDescription < BinData
    endian little

    int32 :endpoint_url_size, value: ->{ OPC.store endpoint_url.bytesize }
    string :endpoint_url, length: ->{ OPC.calculate endpoint_url_size }

    custom server : ApplicationDescription = ApplicationDescription.new

    int32 :server_certificate_size, value: ->{ OPC.store server_certificate.size }
    bytes :server_certificate, length: ->{ OPC.calculate server_certificate_size }

    enum_field UInt32, security_mode : MessageSecurityMode = MessageSecurityMode::NoSecurity
    int32 :security_policy_uri_length, value: ->{ OPC.store security_policy_uri.bytesize }
    string :security_policy_uri, length: ->{ OPC.calculate security_policy_uri_length }

    int32 :user_identity_tokens_size, value: ->{ OPC.store user_identity_tokens.size }
    array user_identity_tokens : UserTokenPolicy, length: ->{ OPC.calculate user_identity_tokens_size }

    int32 :transport_profile_uri_length, value: ->{ OPC.store transport_profile_uri.bytesize }
    string :transport_profile_uri, length: ->{ OPC.calculate transport_profile_uri_length }

    # Just here so you can sort on security level (higher is better)
    uint8 :security_level
  end

  class GetEndPointsResponse < BinData
    endian little

    custom response_header : ResponseHeader = ResponseHeader.new
    int32 :endpoints_size, value: ->{ OPC.store endpoints.size }
    array endpoints : EndPointDescription, length: ->{ OPC.calculate endpoints_size }
  end

  class CloseSecureChannel < BinData
    endian little

    custom sequence_header : SequenceHeader = SequenceHeader.new
    custom request_indicator : NodeID = NodeID.new
    custom request_header : RequestHeader = RequestHeader.new
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
      secure.request_indicator.four_byte_data = ObjectId[:open_secure_channel_request_encoding_default_binary]
      secure.security_header.security_policy_uri = "http://opcfoundation.org/UA/SecurityPolicy#None"
      msg_bytes = secure.to_slice

      header = MessageHeader.new
      header.message_type = MESSAGE_TYPE[:open_secure_channel]
      header.chunk_indicator = CHUNK_TYPE[:final]
      header.size = (msg_bytes.size + 8).to_u32

      {header.to_slice, msg_bytes}
    end

    # This assumes no session has been started (just an insecure secure channel opened)
    def get_end_points(channel_id, token_id, sequence_number, request_id, endpoint_url)
      request = GetEndPointsRequest.new
      request.security_header.secure_channel_id = channel_id.to_u32
      request.security_header.token_id = token_id.to_u32
      request.sequence_header.sequence_number = sequence_number.to_u32
      request.sequence_header.request_id = request_id.to_u32
      request.request_indicator.node_type = TypeOfNodeID::FourByte
      request.request_indicator.four_byte_data = ObjectId[:get_endpoints_request_encoding_default_binary]

      request.endpoint_url = endpoint_url

      msg_bytes = request.to_slice
      header = MessageHeader.new
      header.message_type = MESSAGE_TYPE[:message]
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
        when "ERR"
          client.read_bytes OPC::ErrorMessage
          # NOTE:: Some servers return OPN as a response here
          # ... need to
        when "MSG", "OPN"
          security_header = client.read_bytes OPC::AsymmetricSecurityHeader

          # TODO:: remainder of the message may be encrypted (decrypt here)
          # Although the initial connection should be clear text to discover what
          # encryption standards are supported.
          sequence_header = client.read_bytes OPC::SequenceHeader
          request_indicator = client.read_bytes OPC::NodeID
          response_type = ObjectLookup[request_indicator.four_byte_data]?

          case response_type
          when :open_secure_channel_response, :open_secure_channel_response_encoding_default_binary
            channel_details = client.read_bytes OpenSecureChannelResponse
            query_end_points(client, connection_string, channel_details)
          else
            raise "Unexpected response: #{response_type.to_s}"
          end
        else
          raise "Unexpected response: #{header.message_type}"

          # TODO:: parse the open secure channel response
          raw_data = Bytes.new(2048)
          bytes_read = client.read raw_data
          data = raw_data[0, bytes_read]
          puts header.inspect
          raise data.to_s
        end
      ensure
        client.close
      end
    end

    def query_end_points(client : TCPSocket, connection : String, channel_details : OpenSecureChannelResponse)
      channel_id = channel_details.security_token.channel_id
      token_id = channel_details.security_token.token_id

      # Open message was sequence number 1
      sequence_number = 2
      request_id = 2

      # We want to obtain the list of security standards supported
      header, msg = get_end_points(channel_id, token_id, sequence_number, request_id, connection)
      client.write header
      client.write msg
      client.flush

      header = client.read_bytes OPC::MessageHeader
      case header.message_type
      when "ERR"
        client.read_bytes OPC::ErrorMessage
      when "MSG"
        # TODO:: read the channel ID, then rewind to parse header
        security_header = client.read_bytes OPC::SymmetricSecurityHeader

        # TODO:: remainder of the message may be encrypted (decrypt here)
        # Although the initial connection should be clear text to discover what
        # encryption standards are supported.
        sequence_header = client.read_bytes OPC::SequenceHeader
        request_indicator = client.read_bytes OPC::NodeID
        response_type = ObjectLookup[request_indicator.four_byte_data]?

        case response_type
        when :get_endpoints_response, :get_endpoints_response_encoding_default_binary
          endpoints_response = client.read_bytes GetEndPointsResponse
          parts = close_channel(channel_id, token_id)
          parts.each { |bytes| client.write(bytes) }
          client.flush

          endpoints_response
        else
          raise "Unexpected response: #{response_type.to_s}"
        end
      else
        # TODO:: parse the open secure channel response
        raw_data = Bytes.new(2048)
        bytes_read = client.read raw_data
        data = raw_data[0, bytes_read]
        raise data.to_s
      end
    end

    def close_channel(channel_id, token_id)
      # Open message was sequence number 1
      sequence_number = 3
      request_id = 3

      # TODO:: detect the type of security header that should be used
      sec_header = SymmetricSecurityHeader.new
      sec_header.secure_channel_id = channel_id.to_u32
      sec_header.token_id = token_id.to_u32

      request = CloseSecureChannel.new
      request.sequence_header.sequence_number = sequence_number.to_u32
      request.sequence_header.request_id = request_id.to_u32
      request.request_indicator = OPC.request_indicator(:close_secure_channel_request_encoding_default_binary)

      sec_bytes = sec_header.to_slice
      request_bytes = request.to_slice

      header = MessageHeader.new
      header.message_type = MESSAGE_TYPE[:close_secure_channel]
      header.chunk_indicator = CHUNK_TYPE[:final]
      header.size = (sec_bytes.size + request_bytes.size + 8).to_u32

      {header.to_slice, sec_bytes, request_bytes}
    end
  end
end

require "./opc/*"
