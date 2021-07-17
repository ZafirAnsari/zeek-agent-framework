module ZeekAgent;

export {
#############
    redef enum Log::ID += {MYLOG};
############    

    type ConnectionTuple: record {
            local_address: addr &default=0.0.0.0;
            remote_address: addr &default=0.0.0.0;
            local_port: int &default=0;
            remote_port: int &default=0;
    };

    type SocketInfo: record {
            seuid: string &log;
            connection: ConnectionTuple &default=[] &log;
    };

    global socket_events_state: table[string] of vector of SocketInfo;
    ## add socket info to the state
    global socket_event_add_worker: event(host_id: string, socket_info: ZeekAgent::SocketInfo);
    ## Mapping from ip address to hosts ids
    global ipaddr_to_host: table[string] of set[string];
}

## writing debug logs
event zeek_init()
{
        Log::create_stream(ZeekAgent::MYLOG, [$columns=ZeekAgent::SocketInfo, $path="Zeek-temporary"]);
}


