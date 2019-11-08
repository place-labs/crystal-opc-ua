
class OPC::RequestHeader < BinData
  endian little

  custom authentication_token : NodeID = NodeID.new
  # A DateTime value shall be encoded as a 64-bit signed integer
  # (see Clause 5.2.2.2) which represents the
  # number of 100 nanosecond intervals since January 1, 1601 (UTC).
  # 10_000_000 == 1 second in 100 nanosecond intervals
  # unix * 10_000_000 + 116444736000000000 == timestamp
  uint64 timestamp, value: ->{ OPC.time_to_ua_datetime(Time.utc) }
  uint32 request_handle, default: 1
  uint32 return_diagnostics

  # For tracking requests through different systems
  int32 :audit_entry_id_size, value: ->{ OPC.store audit_entry_id.bytesize }
  string :audit_entry_id, length: ->{ OPC.calculate audit_entry_id_size }

  # How long the client is willing to wait for a response (optional)
  uint32 :timeout_hint
  custom additional_header : ExtensionObject = ExtensionObject.new
end
