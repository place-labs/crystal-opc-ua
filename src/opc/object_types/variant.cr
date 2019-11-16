
module OPC
  alias GUID = UInt128
  alias DateTime = UInt64
  alias XmlElement = GenericString
  alias StatusCode = UInt32

  @[Flags]
  enum VariantArray
    ArrayDimensions
    ArrayValues
  end

  # https://reference.opcfoundation.org/v104/Core/docs/Part6/5.1.2/#Table1
  enum VariantDataType
    None = 0
    Boolean
    Int8
    UInt8
    Int16
    UInt16
    Int32
    UInt32
    Int64
    UInt64
    Float32
    Float64
    GenericString
    DateTime # UInt64
    GUID # UInt128
    GenericBytes
    XmlElement # String
    NodeID
    ExpandedNodeID
    StatusCode # UInt32
    QualifiedName # String with namespace
    LocalizedText # String with locale
    ExtensionObject
    DataValue
    Variant
    DiagnosticInfo
  end

  # https://reference.opcfoundation.org/v104/Core/docs/Part6/5.2.2/#5.2.2.16
  class Variant < BinData
    endian little

    bit_field do
      enum_bits 2, arrays : VariantArray = VariantArray::None
      enum_bits 6, data_type : VariantDataType = VariantDataType::None
    end

    def is_nil?
      data_type.none?
    end

    # Grouped for performance
    group :single_data, onlyif: ->{ arrays.none? } do
      {% for member in VariantDataType.constants %}
        {% if member.stringify != "None" %}
          custom {{member.stringify.downcase.id}} : {{member}}?, onlyif: ->{ parent.data_type == VariantDataType::{{member}} }
        {% end %}
      {% end %}
    end

    group :array_data, onlyif: ->{ arrays.array_values? } do
      # NOTE:: must manually set the array size
      int32 array_size

      {% for member in VariantDataType.constants %}
        {% if member.stringify != "None" %}
          array {{member.stringify.downcase.id}} : {{member}}, length: ->{ OPC.calculate array_size }, onlyif: ->{ self.parent.data_type == VariantDataType::{{member}} }
        {% end %}
      {% end %}

      # NOTE:: Not sure if this works.. How can you de-serialise the above without
      # knowning the value of these dimensions first? Catch 22 when de-serialising
      # Bad OPC UA
      OPC.array dimensions : Int32, onlyif: ->{ parent.arrays.array_dimensions? }
    end
  end
end
