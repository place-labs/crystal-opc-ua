
# https://reference.opcfoundation.org/v104/Core/docs/Part6/5.2.2/#5.2.2.10
class OPC::ExpandedNodeID < BinData
  endian little

  custom node_id : NodeID = NodeID.new

  # TODO:: onlyif certain values of the above node id are present
  OPC.string audit_entry_id
  uint32 server_index
end
