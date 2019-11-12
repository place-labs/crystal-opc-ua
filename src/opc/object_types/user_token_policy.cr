
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

    OPC.string :policy_id

    enum_field UInt32, token_type : UserTokenType = UserTokenType::Anonymous

    OPC.string :issued_token_type
    OPC.string :issuer_endpoint_url
    OPC.string :security_policy_uri
  end
end
