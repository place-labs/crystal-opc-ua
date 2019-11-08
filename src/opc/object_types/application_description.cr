
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
end
