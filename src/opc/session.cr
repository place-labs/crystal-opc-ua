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
    message = promise.get.not_nil!

    response = message.read_bytes CreateSessionResponse
    @timeout = response.session_timeout.to_i
    @session_id = response.session_id

    @state = State::SessionOpen
    self
  end

  def activate : Session
    return self if activated?
    open if !opened?

    # Activate session
    activate = ActivateSessionRequest.new
    activate.request_header.authentication_token = @session_id
    activate.user_identity.type = ObjectId[:anonymous_identity_token_encoding_default_binary]
    activate.user_identity.data = "crystalopc-anonymous-policy".to_slice
    activate.locale_ids << GenericString.new("en-AU")

    # Parse activation response
    promise = @channel.perform_send activate.to_slice
    message = promise.get.not_nil!

    response = message.read_bytes ActivateSessionResponse
    @activated = true
    @state = State::SessionActivated

    self
  end

  def send(message)
    message.request_header.authentication_token = @session_id
    promise = @channel.perform_send message.to_slice
    promise.get.not_nil!
  end
end
