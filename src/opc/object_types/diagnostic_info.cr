
module OPC
  @[Flags]
  enum DiagnosticMask
    SymbolicId
    Namespace
    LocalizedText
    Locale
    AdditionalInfo
    InnerStatusCode
    InnerDiagnosticInfo
  end

  # https://reference.opcfoundation.org/v104/Core/docs/Part6/5.2.2/#5.2.2.12
  class OPC::DiagnosticInfo < BinData
    endian little

    enum_field UInt8, mask : DiagnosticMask = DiagnosticMask::None

    int32 symbolic_id, onlyif: ->{ mask.symbolic_id? }
    int32 namespace_uri_index, onlyif: ->{ mask.namespace? }
    int32 locale, onlyif: ->{ mask.locale? }
    int32 localized_text, onlyif: ->{ mask.localized_text? }
    OPC.string additional_info, onlyif: ->{ mask.additional_info? }
    uint32 inner_status_code, onlyif: ->{ mask.inner_status_code? }
    custom inner_diagnostic_info : DiagnosticInfo = DiagnosticInfo.new, onlyif: ->{ mask.inner_diagnostic_info? }
  end
end
