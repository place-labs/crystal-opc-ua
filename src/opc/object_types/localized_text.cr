
module OPC
  # https://reference.opcfoundation.org/v104/Core/docs/Part6/5.2.2/#Table13
  @[Flags]
  enum LocalizedTextFlags
    Locale # 1
    Text   # 2
  end

  # https://reference.opcfoundation.org/v104/Core/docs/Part6/5.2.2/#Table13
  class LocalizedText < BinData
    endian little

    enum_field UInt8, mask : LocalizedTextFlags = LocalizedTextFlags::None

    int32 :locale_size, value: ->{ OPC.store locale.bytesize }, onlyif: ->{ mask.locale? }
    string :locale, length: ->{ OPC.calculate locale_size }, onlyif: ->{ mask.locale? }

    int32 :text_size, value: ->{ OPC.store text.bytesize }, onlyif: ->{ mask.text? }
    string :text, length: ->{ OPC.calculate text_size }, onlyif: ->{ mask.text? }
  end
end
