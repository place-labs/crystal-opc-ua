# Both session and channels have timeouts that need to be managed
require "tasker"
require "promise"
require "logger"
require "uuid"

# https://reference.opcfoundation.org/v104/Core/docs/Part4/5.6.2/
# OPC Channels are a conduit for session data. We should be able to cleanly
# seperate the two
class OPC::Session
  enum State
    Idle
    SessionRequested
    SessionOpen
    SessionActivated
    SessionClosed
  end

  def initialize(@channel : OPC::Channel, @security_policy : EndPointDescription, @logger = Logger.new(STDOUT))
    @state = State::Idle
    @activated = false

    @timeout = 0
    @session_id = NodeID.new
    @auth_token = NodeID.new

    @request_handle = 2_u32
  end

  property channel : OPC::Channel

  def channel=(@channel) : OPC::Channel
    return @channel if @state == State::SessionClosed

    activated = @activated
    @activated = false

    # If we have not activated already let's not do it automatically here
    if activated
      @state = State::SessionOpen
      activate
    end
  end

  def activated?
    @activated
  end

  def open?
    {State::SessionOpen, State::SessionActivated}.includes?(@state)
  end

  def open : Session
    return self if open?
    raise "cannot reuse closed session" if @state == State::SessionClosed
    raise "session negotiation in progress" if @state == State::SessionRequested

    @state = State::SessionRequested

    session = CreateSessionRequest.new
    session.client_description.application_uri = "urn:CrystalOPC:UaClient"
    session.client_description.product_uri = "urn:acaprojects.com:UaClient"
    session.client_description.application_name.text = "CrystalOPC:UaClient"
    session.server_uri = @security_policy.server.application_uri
    session.endpoint_url = @security_policy.endpoint_url
    session.session_name = UUID.random.to_s
    session.session_timeout = 3600000_f64

    # Obtain create Session response
    promise = @channel.perform_send session.to_slice
    io = promise.get.not_nil!

    check_response(io, :create_session_response, :create_session_response_encoding_default_binary)

    response = io.read_bytes CreateSessionResponse
    @timeout = response.session_timeout.to_i
    @session_id = response.session_id
    @auth_token = response.authentication_token

    @state = State::SessionOpen
    self
  end

  def activate : Session
    return self if activated?
    open if !open?

    # Activate session
    activate = ActivateSessionRequest.new
    activate.request_header.authentication_token = @auth_token

    activate.user_identity.type = ObjectId[:anonymous_identity_token_encoding_default_binary]
    activate.user_identity.data = "open62541-anonymous-policy".to_slice
    activate.locale_ids << GenericString.new("en-AU")

    # Parse activation response
    promise = @channel.perform_send activate.to_slice
    io = promise.get.not_nil!

    check_response(io, :activate_session_response, :activate_session_response_encoding_default_binary)

    response = io.read_bytes ActivateSessionResponse
    @activated = true
    @state = State::SessionActivated

    self
  end

  def send(message)
    activate

    @request_handle += 1
    message.request_header.authentication_token = @auth_token
    message.request_header.request_handle = @request_handle
    promise = @channel.perform_send message.to_slice
    promise.get.not_nil!
  end

  def read(value) : ReadResponse
    req = OPC::ReadRequest.new
    read = OPC::ReadValueId.new(value)
    req.nodes_to_read << read
    io = send req

    check_response(io, :read_response, :read_response_encoding_default_binary)
    io.read_bytes(ReadResponse)
  end

  def check_response(io, *codes)
    node_id = io.read_bytes(NodeID)
    response_code = ObjectLookup[node_id.four_byte_data]

    if !codes.includes?(response_code)
      response = io.read_bytes(ResponseHeader)
      if response.service_result == 0_u32
        error = UnexpectedMessage.new "unexpected response #{response_code} (node_id.four_byte_data)"
        io.rewind
        error.message_data = io
        raise error
      else
        # :service_fault, :service_fault_encoding_default_binary
        error, description = STATUS_DESCRIPTION[response.service_result]
        error = Error.new "#{error}: #{description} (0x#{response.service_result.to_s(16)})"
        error.error_code = response.service_result
        raise error
      end
    end
  end

  def close

  end
end
