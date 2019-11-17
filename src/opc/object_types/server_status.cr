
module OPC
  # https://reference.opcfoundation.org/v104/Core/DataTypes/BuildInfo/
  class BuildInfo < BinData
    endian little

    OPC.string product_uri
    OPC.string manufacturer_name
    OPC.string product_name
    OPC.string software_version
    OPC.string build_number
    uint64 build_date
  end

  enum ServerState
    Running
    Failed
    NoConfiguration
    Suspended
    Shutdown
    Test
    CommunicationFault
    Unknown
  end

  # https://reference.opcfoundation.org/v104/Core/docs/Part5/12.10/
  class ServerStatus < BinData
    endian little

    uint64 start_time
    uint64 current_time
    enum_field UInt32, server_state : ServerState = ServerState::Running
    custom build_info : BuildInfo = BuildInfo.new
    uint32 seconds_till_shutdown
    custom shutdown_reason : LocalizedText = LocalizedText.new
  end
end
