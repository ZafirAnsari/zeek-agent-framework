#! Log attribution with agent_socket_events by extending conn.log

module ZeekAgent;

#This event will be fired to remove an entry from socket_events_state when a connection has been attributed to its socket events
export{
    global socket_remove_after_attribution: event(host_id: string, input_connection: connection, src: bool);
}


# Add attribution fields to the conn.log record.
redef record Conn::Info += {
    # agent_socket_events.log seuid on the originating system
    orig_seuids: set[string] &optional &log;

    # agent_socket_events.log seuid on the responding system
    resp_seuids: set[string] &optional &log;
};

hook ZeekAgent::connection_attributing(c: connection, src_attributions: vector of ZeekAgent::SocketInfo, dst_attributions: vector of ZeekAgent::SocketInfo)
    {

    local socket: ZeekAgent::SocketInfo;

    for ( idx in src_attributions ) {
        socket = src_attributions[idx];
        if (!c$conn?$orig_seuids) {c$conn$orig_seuids = set(socket$seuid);}
        else {add c$conn$orig_seuids[socket$seuid];}
    }

    for ( idx in dst_attributions ) {
        socket = dst_attributions[idx];
        if (!c$conn?$resp_seuids) {c$conn$resp_seuids = set(socket$seuid);}
        else {add c$conn$resp_seuids[socket$seuid];}
    }

    #The following code will remove the attributed socket events from socket_event_states
    local src_host_ids = ZeekAgent::getHostIDsByAddress(c$id$orig_h);
    local dst_host_ids = ZeekAgent::getHostIDsByAddress(c$id$resp_h);

    for(host_id in src_host_ids){
        event socket_remove_after_attribution(host_id,c,T);
    }

    for(host_id in dst_host_ids){
        event socket_remove_after_attribution(host_id,c,F);
    }

}
