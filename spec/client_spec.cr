require "./helper"

describe OPC do
  it "should parse a node id" do
    io = IO::Memory.new "\x01\x00\x7a\x02".to_slice
    node = io.read_bytes OPC::NodeID
    node.node_type.should eq(OPC::TypeOfNodeID::FourByte)
    node.flags.none?.should eq(true)
    node.four_byte_data.should eq(634)
    node.to_slice.should eq(io.to_slice)

    io = IO::Memory.new "\x04\x01\x00\x46\x57\xc1\x39\xa7\x50\x81\xd8\xe0\x4e\x94\x79\xfe\x4f\xf4\x8f".to_slice
    node = io.read_bytes OPC::NodeID
    node.node_type.should eq(OPC::TypeOfNodeID::GUID)
    node.flags.none?.should eq(true)
    node.namespace.should eq(1)
    node.to_slice.should eq(io.to_slice)
  end

  it "should negotiate an insecure secure channel with mtconnect" do
    server = "opc.mtconnect.org"
    port = 4840
    client = TCPSocket.new(server, port)

    channel = OPC::Channel.new client
    channel.open "opc.tcp://opc.mtconnect.org:4840"
    policies = channel.security_policies
    session = OPC::Session.new(channel, policies[-1])
    session.open
    session.activate

    result = session.read OPC::ObjectId[:server_server_status], 0x0d_u32
    result.results[0].error?
    if obj = result.results[0].extensionobject
    	obj.extract OPC::ServerStatus
    else
      raise "failed to obtain server status"
    end
  end

  it "should negotiate an insecure secure channel with rocks" do
    server = "opcua.rocks"
    port = 4840
    client = TCPSocket.new(server, port)

    channel = OPC::Channel.new client
    channel.open "opc.tcp://opcua.rocks:4840"
    policies = channel.security_policies
    session = OPC::Session.new(channel, policies[-1])
    session.open
    session.activate

    result = session.read OPC::ObjectId[:server_server_status], 0x0d_u32
    result.results[0].error?
    if obj = result.results[0].extensionobject
    	obj.extract OPC::ServerStatus
    else
      raise "failed to obtain server status"
    end
  end
end
