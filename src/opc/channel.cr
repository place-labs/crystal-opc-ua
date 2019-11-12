# Both session and channels have timeouts that need to be managed
require "tasker"
require "promise"
require "logger"

# https://reference.opcfoundation.org/v104/Core/docs/Part4/5.6.2/
# OPC Channels are a conduit for session data. We should be able to cleanly
# seperate the two
class OPC::Channel # < IO
  # TODO:: implement channel as an IO
  enum State
    Idle
    HelloSent
    ChannelRequested
    ChannelOpen
    ChannelClosed
  end

  alias Response = IO::Memory?

  def initialize(io : IO, @logger = Logger.new(STDOUT))
    io.sync = false if io.responds_to?(:sync)
    @io = io
    @state = State::Idle
    @closed = false
    @write_mutex = Mutex.new

    # Security settings
    @symmetric_header = false
    @security_policy = "http://opcfoundation.org/UA/SecurityPolicy#None"
    @endpoint_url = ""

    # Request tracking
    @request_id = 0_u32
    @sequence_number = 0_u32
    @channel_id = 0_u32
    @token_id = 0_u32
    @requests = {} of UInt32 => ::Promise::DeferredPromise(Response)
    @security_policies = [] of EndPointDescription

    # Message extraction
    @parts = [] of Bytes
    @buffer = Tokenizer.new do |io|
      if io.size >= 8
        header = io.read_bytes(MessageHeader)
        header.size.to_i
      else
        -1
      end
    end

    spawn { self.consume_io }
  end

  getter endpoint_url

  def open?
    @state == State::ChannelOpen
  end

  def negotiating?
    {State::HelloSent, State::ChannelRequested}.includes?(@state)
  end

  def send(message) : Response
    raise "channel not open" unless open?
    perform_send(message.to_slice).get.not_nil!
  end

  def perform_send(message : Bytes, message_type = :message, expect_response = true)
    # TODO:: determine if we need to split up this message

    request_id = next_request_id
    squence_num = @sequence_number

    # TODO:: timeout the message
    promise = ::Promise::DeferredPromise(Response).new
    @requests[request_id] = promise if expect_response

    security_header = if @symmetric_header
                        sym_header = SymmetricSecurityHeader.new
                        sym_header.secure_channel_id = @channel_id
                        sym_header.token_id = @token_id
                        sym_header
                      else
                        # TODO:: configure certificates
                        asym_header = AsymmetricSecurityHeader.new
                        asym_header.secure_channel_id = @channel_id
                        asym_header.security_policy_uri = @security_policy
                        asym_header
                      end
    security_header = security_header.to_slice

    sequence_header = SequenceHeader.new
    sequence_header.request_id = request_id
    sequence_header.sequence_number = squence_num
    sequence_header = sequence_header.to_slice

    header = MessageHeader.new
    header.message_type = MESSAGE_TYPE[message_type]
    header.chunk_indicator = CHUNK_TYPE[:final]
    header.size = (message.size + security_header.size + sequence_header.size + 8).to_u32

    write_parts header.to_slice, security_header.to_slice, sequence_header.to_slice, message
    promise
  end

  # TODO:: Support additional security methods (currently only none)
  def open(endpoint_url) : Channel
    raise "cannot re-use channel" unless @state == State::Idle
    @endpoint_url = endpoint_url

    # Hello (request 0)
    @state == State::HelloSent
    promise = ::Promise::DeferredPromise(Response).new
    @requests[0_u32] = promise
    write_parts *hello(endpoint_url)

    # Acknowledge
    message = promise.get.not_nil!
    header = expecting(message, "ACK")
    acknowledge = message.read_bytes AcknowledgeMessage

    # TODO:: configure the max message size etc from acknowledge message

    # Open Channel
    promise = perform_send(open_channel.to_slice, :open_secure_channel)

    # Open Channel response
    message = promise.get.not_nil!
    position = message.pos
    header = expecting(message, "MSG", "OPN")

    # TODO:: save anything we need to
    security_header = message.read_bytes AsymmetricSecurityHeader

    message.pos = position
    request_indicator = message.read_bytes NodeID
    response_type = ObjectLookup[request_indicator.four_byte_data]?

    channel_details = case response_type
                      when :open_secure_channel_response, :open_secure_channel_response_encoding_default_binary
                        message.read_bytes OpenSecureChannelResponse
                      else
                        error = UnexpectedMessage.new "unexpected response: #{response_type} (#{request_indicator.four_byte_data}) - expecting :open_secure_channel_response, :open_secure_channel_response_encoding_default_binary"
                        error.message_data = message
                        raise error
                      end

    @channel_id = channel_details.security_token.channel_id
    @token_id = channel_details.security_token.token_id
    @state = State::ChannelOpen

    # TODO:: adjust security settings based on channel details
    @symmetric_header = true

    # Check if the channel was closed while negotiating
    close if @closed
    self
  end

  macro expecting(message, *types)
    %message = {{message}}
    %message.rewind
    %header = %message.read_bytes MessageHeader

    # Check the header message types
    case %header.message_type
    when {{*types}}
      %header
    when "ERR"
      # The remote side has returned an error
      %opc_error = %message.read_bytes(ErrorMessage)
      %error = Error.new("OPC error response: #{%opc_error.reason} (#{%opc_error.code})")
      %error.error_code = %opc_error.code
      raise %error
    else
      # Unexpected message data is returned in the error for debugging
      %error = UnexpectedMessage.new "unexpected response #{%header.message_type} - expecting #{{{types}}}"
      %error.message_data = %message
      raise %error
    end
  end

  def close : Nil
    return if @state == State::ChannelClosed
    @closed = true
    @state = State::ChannelClosed if @io.closed?
    return unless open?

    @state = State::ChannelClosed
    msg = OPC.request_indicator(:close_secure_channel_request_encoding_default_binary)
    perform_send(msg.to_slice, :close_secure_channel, expect_response: false)
  end

  # Allow these to be cached
  def security_policies=(policies : Array(EndPointDescription))
    @security_policies = policies
  end

  def security_policies
    return @security_policies unless @security_policies.empty?
    raise "channel not open" unless open?

    request = GetEndPointsRequest.new
    request.endpoint_url = @endpoint_url
    response = send(request)
    request_indicator = response.read_bytes NodeID
    resp = response.read_bytes GetEndPointsResponse

    @security_policies = resp.endpoints.sort { |a, b| a.security_level <=> b.security_level }
  end

  protected def write_parts(*parts)
    STDOUT.sync = true
    puts "writing:\n #{parts}"
    @write_mutex.synchronize do
      parts.each { |bytes| @io.write bytes }
      @io.flush
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
    # TODO:: configure alternative security types
    secure.security_mode = MessageSecurityMode::NoSecurity
    secure.requested_lifetime = 1.hour.total_milliseconds.to_u32
    secure
  end

  protected def next_request_id
    @sequence_number += 1
    @request_id += 1
    @request_id
  end

  protected def process_response(io : IO::Memory) : Nil
    header = io.read_bytes MessageHeader
    message_type = header.message_type

    #@logger.debug { "received #{message_type}" }
    puts "received:\n #{message_type}"

    case message_type
    when "MSG", "OPN"
      # TODO:: check for expected type of header
      security_header = if @symmetric_header
                          io.read_bytes SymmetricSecurityHeader
                        else
                          io.read_bytes AsymmetricSecurityHeader
                        end

      if open? && @channel_id != security_header.secure_channel_id
        close
        raise "received invalid channel id #{security_header.secure_channel_id}, channel ID is #{@channel_id}"
      end

      # TODO:: remainder of the message may be encrypted (decrypt here)
      # Although the initial connection should be clear text to discover what
      # encryption standards are supported.
      sequence_header = io.read_bytes SequenceHeader
      if request = @requests[sequence_header.request_id]?
        request.resolve(io)
      else
        close
        raise "no matching request id #{sequence_header.request_id}"
      end
    when "ACK"
      @requests[0].resolve(io)
    when "ERR"
      err = io.read_bytes ErrorMessage
      error = Error.new("#{err.reason} (#{err.code})")
      error.error_code = err.code
      puts error.message
      @requests[0].reject(error)
    when "RHE"
      rhello = io.read_bytes ReverseHelloMessage
      open(rhello.endpoint_url)
    else
      # TODO:: log unexpcted message type
    end
  end

  protected def extract(message)
    if message[3] == 'F'.ord
      begin
        if @parts.size > 0
          @parts << message
          parts = @parts
          @parts = [] of Bytes
          # TODO:: merge and send all parts as a single message
          # i.e. don't just send the first part like we're doing here
          process_response IO::Memory.new(parts[0], false)
        else
          process_response IO::Memory.new(message, false)
        end
      rescue e
        # TODO:: log error
      end
    else
      @parts << message
    end
  end

  private def consume_io
    raw_data = Bytes.new(4096)

    while !@io.closed?
      bytes_read = @io.read(raw_data)
      break if bytes_read == 0 # IO was closed

      @buffer.extract(raw_data[0, bytes_read]).each do |message|
        extract(message)
      end
    end
  rescue IO::Error
  rescue Errno
    # Input stream closed. This should only occur on termination
  ensure
    @state = State::ChannelClosed

    # TODO:: cancel any timers
    # @timeouts.try &.cancel

    # TODO:: reject any pending requests
  end
end
