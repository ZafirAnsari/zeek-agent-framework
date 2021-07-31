
# About

This Zeek script framework communicates with the [Zeek
Agent](https://github.com/zeek/zeek-agent) to perform live
queries against the agent's tables and then incorporate the results
back into Zeek's processing & logging. In addition to tables built in,
the agent can connect to [Osquery](https://osquery.io) to retrieve any
of the host data provided there.

*Note*: This framework is still a work in progress and expected to
change further in terms of API, functionality, and implementation.

# Prerequisites

The framework requires Zeek 3.0+, which you can download and install
per the instructions on the [Zeek web site](https://zeek.org/download).

You will also need to install the Zeek Agent itself, as well as
optionally Osquery, according to [these
instructions](https://github.com/zeek/zeek-agent-framework).

# Installation

The easiest way to install the `zeek-agent` framework is through the
[Zeek package
manager](https://docs.zeek.org/projects/package-manager/en/stable/index.html).
If you have not installed the package manager yet, do that first:

    # pip install zkg
    # zkg autoconfig

    # zkg install zeek/zeek-agent-framework

Alternatively, you can clone the repository manually and copy it over
into Zeek's `site` folder:

    # git clone https://github.com/zeek/zeek-agent-framework
    # cp -a zeek-agent-framework/zeek-agent $(zeek-config --site_dir)

If you'd rather run it directly out of the local repository clone
(rather than `site`), set your `ZEEKPATH` accordingly:

    # export ZEEKPATH=<path/to/zeek-agent-framework>:$(zeek-config --zeekpath)

# Usage

Using any of the three installation methods above, you can now load
the framework when you start Zeek:

    # zeek zeek-agent

Once you start up any agents, you should start seeing a new Zeek log
file `zeek-agent.log` that records the hosts connecting to Zeek:

    # cat zeek-agent.log
    #fields    ts       source  peer        level   message
    1576768875.018249	local	ZeekMaster	info	Subscribing to zeek announce topic /zeek/zeek-agent/zeek_announce
    1576768875.018249	local	ZeekMaster	info	Subscribing to zeek individual topic /zeek/zeek-agent/zeek/C6EAF3CFDF46831E2D9103E5A1C48F78AD873A00#10223
    1576768877.709030	local	ZeekMaster	info	Incoming connection established from C6EAF3CFDF46831E2D9103E5A1C48F78AD873A3C#7503

You won't see much more at first as there's nothing sending queries to
the endhost yet. Check out the `examples/` directory for scripts that
are using the built in (currently Linux audit based) and Osquery based
functionality.

# Examples

The framework ships with examples that currently use Osquery derived tables
and Linux auditd based tables.  Use the follow lines to load all of the
associated examples.

To load the Osquery examples:

    @load zeek-agent/examples/osquery

To load the auditd examples:

    @load zeek-agent/examples/auditd

To load the EndpointSecurity (MacOS) examples:

    @load zeek-agent/examples/endpointsecurity


# Credits

This Zeek framework is based on an earlier implementation by [Steffen
Haas](https://github.com/iBigQ), with recent work contributed by
[Corelight](https://www.corelight.com) and [Trail of
Bits](https://www.trailofbits.com).




# Goal
Our goal is to correlate and attribute socket events to its corresponding network logs. In order to correlate zeek network logs and host events, zeek must receive the host events from zeek-agent so that they can be correlated on zeek (already having network logs).  Zeek requests zeek-agent to send host events. It does so by sending scheduled sql queries via broker to zeek-agent. The sql queries determine the type of host events zeek wants such as process events, file events or socket events. An example of such an sql query would be "SELECT syscall FROM socket_events;".
# Why SQL
The reason why zeek agent use sql to fetch host events is because not only it provides better performance but also because it is very convenient, we can easily fetch an "attribute" of our liking such as syscall belonging to a "concept" such as a socket event and also add constraints as per our requirement such as "WHERE syscall != fork;". these OS concepts and their attributes are shared among different operating systems thereby making sql queries very convenient.
# Workflow
Once zeek sends an sql query to zeek-agent, it waits for a response from zeek-agent which in-turn sends the corresponding events from its virtual table (a table maintaining state of os events of a host in zeek-agent) back to zeek. (We will come back to as to how a query is sent from zeek, but before that lets explore what happens when an event(response) is received by zeek)

Zeek must maintain incoming events (including their host ids) from zeek-agent in a table so that they can be later attributed to a network log. When a new socket event arrives on zeek, the event "socket_event_add" in set_state.zeek is triggered, it fetches the socket event and then calls another event "socket_event_add_worker" in helper.zeek which is responsible for adding a new socket entry to the table. The table responsible for maintaining the state of socket events is "socket_event_states". The key of "socket_event_states" is the host_id(id unique to a host) and the value is a vector of seuid, local address, remort address, local port and remote port. seuid is a unique id from socket_events table in zeek-agent.

Next, in main.zeek (attribution folder), whenever a new network connection arrives (after a certain delay, during which zeek waits for arrival of socket events from zeek-agent), its host_id (id unique to a host) is first fetched from the function "getHostIDsByAddress". The event "getSocketInfoByHostIDByConnection" in get_state.zeek uses this host_id and the incoming network connection to return the socket event that correlates with the network connection. The flow of this function is as follows: first, the presence of the sockets corresponding to the correct host_id in "socket_event_states"  is checked (this is the same host_id coming from the network connection to ensure that only the socket events and network connections corresponding to a particular host are fetched). Recall: "socket_event_states" is the same table that maintains all socket events and its key is the "host_id". Next, the stored sockets in "socket_event_states[host_id]" are iterated and the socket events that match the input network connection are stored in a vector and returned for later use. The matching of socket events and input connection is done through the function "matchConnectionTuple" in utils.zeek, in which the local address, remote address, local port and remote port of both the socket event and network connection are matched.

The returned socket vector which includes the seuid of the socket event as well its connection tuple, is then used by "connection_attributing" event in conn_log.zeek to finally attribute the seuid (unique id of a socket_event table entry) to the connection. The attribution is done for both originater socket events as well as responder socket events, after which an additional column is added to the network log (conn.log) containing the seuids of originator or the responder so that the seuid is attributed to a network log.

Lastly, the attributed socket events are removed from the table maintaining the state of socket events by the event "socket_remove_after_attribution" in helper.zeek






# Flow of subscription (sending of query):
1. The subsribe function is called whenever a query needs to be sent to zeek-agent (subscribe(query)). This function can be found in "zeek_agent_framework.zeek" in the "framework" folder. This function takes in a query, host list and group list as parameters. Host list and group lists are optional parameters. When subscribing, if there are no host list or group list specified then the query is subscribed to all hosts.

2. The subscribe function calls "share subscription" and "insert subscription".
- "insert_subscription" in zeek_agent_subscriptions.zeek is responsible for maintaining the flow of subscription (where the subscription came from and sent to whom) it does so by calling "zeek_subscribe" which  is responsible for keeping the state about the direction the subscription came from.

- In "share_subscription" function in bro_backend.zeek, first a peer name is fetched from broker, these peers are the nodes to which zeek is connected to via broker. Next the table maintaining the state of subscriptions is updated with the new subscription corresponding to the peer. 

3. "share_subscription" then calls "send_subscription".  "send_subscription" parses the data coming from "share_subscription" which includes the topic, such as when broadcasting to all nodes the topic might be "broadcastall" (this is not an actual topic, using it as example here") or "warning" incase of an unexpected event. "send subscription" also has the query as well as the groups and hosts to send it to as its arguments, if no groups or hosts are specified then it has a boolean varaible
"group_flood" turned True which broadcasts the message to all hosts. Finally it sends the message to hosts via broker -> Broker::publish.

# Extra information:
- "zeek-agent-logger" maintains a record of all the queries being sent to a host. each query has a time stamp,host_id, event time, severity and a message attributed to it.

- A query can be sent (subscribed) to specified hosts, a group of hosts or broadcasted to all the hosts present. Queries such as periodic queries (socket,file,process events) are usually sent to all hosts.

- Scheduled queries are sent at 2sec intervals.

- Whenever a zeek agent connects to zeek, zeek subscribes to all the specified hosts/ groups or every host (if not specified) in that zeek-agent.







