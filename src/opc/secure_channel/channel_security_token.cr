
class OPC::ChannelSecurityToken < BinData
  endian little

  uint32 :channel_id
  uint32 :token_id
  uint64 :timestamp
  uint32 :revised_lifetime

  int32 :server_nonce_size, value: ->{ OPC.store server_nonce.size }
  bytes :server_nonce, length: ->{ OPC.calculate server_nonce_size }

  def created_at : Time
    OPC.ua_datetime_to_time timestamp
  end
end
