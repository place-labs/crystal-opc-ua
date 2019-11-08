# Both session and channels have timeouts that need to be managed
require "tasker"

# https://reference.opcfoundation.org/v104/Core/docs/Part4/5.6.2/
# OPC Channels are a conduit for session data. We should be able to cleanly
# seperate the two
class OPC::Channel # < IO
  # TODO:: implement channel as an IO

  enum State
    Idle
    HelloSent
    SecureChannelRequested
    SecureChannelOpen
    SecureChannelClosed
  end

  def initialize(@io : IO, @logger = Logger.new)
    @state = State::Idle
  end
end

class OPC::Session
  enum State
    Idle
    SessionRequested
    SessionOpen
    SessionClosed
  end

  def initialize(@channel : OPC::Channel, @logger = Logger.new)
    @state = State::Idle
  end
end
