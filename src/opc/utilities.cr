
module OPC
  # When storing string or byte array sizes a 0 length should be stored as -1
  def self.store(size)
    size == 0 ? -1 : size
  end

  def self.calculate(size)
    size < 0 ? 0 : size
  end

  # https://github.com/open62541/open62541/blob/9f0c73d6ea3388f858891323f84cb9e321b4a3fb/include/open62541/types.h#L236
  # 10_000_000 == 1 second in 100 nanosecond intervals
  UA_DATETIME_SEC =         10_000_000_u64
  UA_UNIX_EPOCH   = 116444736000000000_u64

  def self.ua_datetime_to_time(time : UInt64) : Time
    Time.from_unix((time - UA_UNIX_EPOCH) / UA_DATETIME_SEC)
  end

  def self.time_to_ua_datetime(time : Time) : UInt64
    (time.to_unix.to_u64 * UA_DATETIME_SEC) + UA_UNIX_EPOCH
  end
end
