
class OPC::ChannelSecurityToken < BinData
  endian little

  uint32 :channel_id
  uint32 :token_id
  uint64 :timestamp
  uint32 :revised_lifetime
  OPC.bytes :server_nonce

  def created_at : Time
    OPC.ua_datetime_to_time timestamp
  end
end
