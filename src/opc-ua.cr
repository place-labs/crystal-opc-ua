require "socket"
require "bindata"
require "tokenizer"

# https://reference.opcfoundation.org/v104/Core/docs/Part6/7.1.2/
# https://reference.opcfoundation.org/v104/Core/docs/Part6/6.7.2/#Table41
# Error codes: https://python-opcua.readthedocs.io/en/latest/_modules/opcua/ua/status_codes.html#StatusCodes

module OPC
  # https://reference.opcfoundation.org/v104/Core/docs/Part6/6.7.2/
  # class MessageFooter
  # TODO:: involves encryption
  # end
  macro string(name, onlyif = nil)
    int32 :{{name.id}}_size, value: ->{ OPC.store {{name.id}}.bytesize }, onlyif: {{onlyif}}
    string :{{name.id}}, length: ->{ OPC.calculate {{name.id}}_size }, onlyif: {{onlyif}}
  end

  macro bytes(name, onlyif = nil)
    int32 :{{name.id}}_size, value: ->{ OPC.store {{name.id}}.size }, onlyif: {{onlyif}}
    bytes :{{name.id}}, length: ->{ OPC.calculate {{name.id}}_size }, onlyif: {{onlyif}}
  end

  macro array(name, onlyif = nil)
    int32 {{name.var}}_size, value: ->{ OPC.store {{name.var}}.size }, onlyif: {{onlyif}}
    array {{name.var}} : {{name.type}}, length: ->{ OPC.calculate {{name.var}}_size }, onlyif: {{onlyif}}
  end

  class UnexpectedMessage < Exception
    property message_data : IO::Memory? = nil
  end

  class Error < Exception
    property error_code : UInt32 = 0
  end

  module Default
    KB = 1024_u32
    MB = 1024_u32 * KB

    ReceiveBufSize = 0xffff_u32
    SendBufSize    = 0xffff_u32
    MaxChunkCount  =    512_u32
    MaxMessageSize = 2_u32 * MB
  end
end

require "./opc/utilities"
require "./opc/object_id"
require "./opc/status_codes"
require "./opc/object_types/*"
require "./opc/secure_channel/*"
require "./opc/session/*"
require "./opc/requests/*"
require "./opc/*"
