
module OPC
  # https://reference.opcfoundation.org/v104/Core/DataTypes/ApplicationType/
  enum ApplicationType
    Server
    Client
    ClientAndServer
    DiscoveryServer
  end

  # https://reference.opcfoundation.org/v104/Core/DataTypes/ApplicationDescription/
  class ApplicationDescription < BinData
    endian little

    OPC.string :application_uri
    OPC.string :product_uri

    custom application_name : LocalizedText = LocalizedText.new
    enum_field UInt32, application_type : ApplicationType = ApplicationType::Client

    OPC.string :gateway_server_uri
    OPC.string :discovery_profile_uri
    OPC.array disovery_urls : GenericString
  end
end
