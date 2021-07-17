module ZeekAgent;

event ZeekAgent::socket_event_add_worker(host_id: string, socket_info: ZeekAgent::SocketInfo)
	{
	if ( host_id in ZeekAgent::socket_events_state ){
		ZeekAgent::socket_events_state[host_id] += socket_info;
	}
	else{
		ZeekAgent::socket_events_state[host_id] = vector(socket_info);
	}
	}

event ZeekAgent::host_ipaddr_add_worker(host_id: string, ip_addr: string) {
	if (ip_addr in ipaddr_to_host){
		add ipaddr_to_host[ip_addr][host_id];
	}else{
		ipaddr_to_host[ip_addr] = set(host_id);
	}
}

# This will remove the sockets event related to the host after the socket events have been attributed to the connection
event socket_remove_after_attribution(host_id :string, input_connection :connection,src :bool){
###################################### Debug statements #############################
       #for(indx in ZeekAgent::socket_events_state[host_id]){
               #local socket1 = ZeekAgent::socket_events_state[host_id][indx];
               #Log::write(ZeekAgent::MYLOG, socket1);
        #}
##################################################################################
        local input_connection_tuple = ZeekAgent::convert_conn_to_conntuple(input_connection, !src);
        local tempVector : vector of SocketInfo = vector();

        for(indx in ZeekAgent::socket_events_state[host_id]){

                local socket = ZeekAgent::socket_events_state[host_id][indx];
                #remove socket record if its not matching
        if (!ZeekAgent::matchConnectionTuple(input_connection_tuple, socket$connection))
        {
                        tempVector += socket;
        }
        }
        ZeekAgent::socket_events_state[host_id] = tempVector;
###################################### Debug statements #############################
       #Log::write(ZeekAgent::MYLOG, [$seuid="Now removing records that have been attributed", $connection=[]]);

        #for(indx in ZeekAgent::socket_events_state[host_id]){
                #local socket2 = ZeekAgent::socket_events_state[host_id][indx];
                #Log::write(ZeekAgent::MYLOG, socket2);
        #}
       #Log::write(ZeekAgent::MYLOG, [$seuid="The process completed successfully", $connection=[]]);
##################################################################################

}

