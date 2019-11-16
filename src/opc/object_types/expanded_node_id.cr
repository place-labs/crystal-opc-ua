
# https://reference.opcfoundation.org/v104/Core/docs/Part6/5.2.2/#5.2.2.10
class OPC::ExpandedNodeID < BinData
  endian little

  # Checks for namespace id size
  custom node_id : NodeID = NodeID.new, value: -> do
    node_id.flags = (node_id.flags | NodeIDFlags::NamespaceUriFlag) if namespace_uri.bytesize > 0
    node_id
  end

  OPC.string namespace_uri, onlyif: ->{ node_id.flags.namespace_uri_flag? }
  uint32 server_index, onlyif: ->{ node_id.flags.server_index_flag? }
end
