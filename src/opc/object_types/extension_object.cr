
module OPC
  # https://reference.opcfoundation.org/v104/Core/docs/Part6/5.2.2/#Table14
  enum BodyEncoding
    NoBody
    ByteString
    XmlElement
  end

  # https://reference.opcfoundation.org/v104/Core/docs/Part6/5.2.2/#Table14
  class ExtensionObject < BinData
    endian little

    custom type_id : NodeID = NodeID.new
    enum_field UInt8, encoding : BodyEncoding = BodyEncoding::NoBody, value: -> do
      if byte_data.size > 0
        BodyEncoding::ByteString
      elsif xml_data.bytesize > 0
        BodyEncoding::XmlElement
      else
        BodyEncoding::NoBody
      end
    end

    int32 :length, value: ->{ OPC.store(encoding == BodyEncoding::ByteString ? byte_data.size : xml_data.bytesize) }, onlyif: ->{ encoding != BodyEncoding::NoBody }
    bytes :byte_data, length: ->{ OPC.calculate length }, onlyif: ->{ encoding == BodyEncoding::ByteString }
    string :xml_data, length: ->{ OPC.calculate length }, onlyif: ->{ encoding == BodyEncoding::XmlElement }

    def type=(value)
      type_id.value = value
    end

    def data=(value)
      if value.is_a?(String)
        encoding = BodyEncoding::XmlElement
        xml_data = value
      end

      if value.is_a?(Bytes)
        encoding = BodyEncoding::ByteString
        byte_data = value
      end

      value
    end
  end
end
