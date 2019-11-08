require "socket"
require "bindata"
require "tokenizer"

# https://reference.opcfoundation.org/v104/Core/docs/Part6/7.1.2/
# https://reference.opcfoundation.org/v104/Core/docs/Part6/6.7.2/#Table41
# Error codes: https://python-opcua.readthedocs.io/en/latest/_modules/opcua/ua/status_codes.html#StatusCodes

module OPC
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
      secure = OpenSecureChannelRequest.new
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

require "./opc/utilities"
require "./opc/object_id"
require "./opc/status_codes"
require "./opc/object_types/*"
require "./opc/secure_channel/*"
require "./opc/*"
