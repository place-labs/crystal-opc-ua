
module OPC
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
end
