#lang forge/temporal

option max_tracelength 40
option min_tracelength 31

option solver Glucose
// making it so that the visualization loads in automatically
option run_sterling "visualization.js"

---------- Definitions ----------

abstract sig State {}

one sig Closed extends State {}
one sig SynReceived extends State {}
one sig SynSent extends State {}
one sig Established extends State {}
one sig FinWait1 extends State {}
one sig FinWait2 extends State {}
one sig TimeWait extends State {}
one sig CloseWait extends State {}
one sig LastAck extends State {}

// A node in the system.
sig Node {
    id: one Int,
    var curState: one State,
    var receiveBuffer: set Packet,
    var sendBuffer: set Packet,
    var seqNum: one Int,
    var ackNum: one Int,
    var connectedNode: lone Node,

    var send_next: one Int,
    var recv_next: one Int
}

// A packet in the system.
sig Packet {
    var src: lone Node,
    var dst: lone Node,
    var pSeqNum: lone Int,
    var pAckNum: lone Int
}

sig DataPacket extends Packet {}
sig AckPacket extends Packet {}
sig FinPacket extends Packet {}

// The network of the system (holding in-transit packets).
one sig Network {
    var packets: set Packet
}

// Predicate that checks a node doesn't change.
pred nodeDoesNotChange[n: Node] {
    n.curState' = n.curState
    n.receiveBuffer' = n.receiveBuffer
    n.sendBuffer' = n.sendBuffer
    n.seqNum' = n.seqNum
    n.ackNum' = n.ackNum
    n.connectedNode' = n.connectedNode
    n.send_next' = n.send_next
    n.recv_next' = n.recv_next
}

// Predicate that checks a packet doesn't change.
pred packetDoesNotChange[p: Packet] {
    p.src' = p.src
    p.dst' = p.dst
    p.pSeqNum' = p.pSeqNum
    p.pAckNum' = p.pAckNum
}

// A predicate that checks if the system is in a valid state.
pred validState {
    // Sequence numbers are non-negative integers
    all n: Node | {
        n.seqNum >= 0
        n.ackNum >= 0
    }

    // For every packet in a network, the source and destination nodes are distinct
    all p: Packet | {
        p.src != none implies p.src != p.dst
    }

    // Any node that is established must be connected to another node
    all n: Node | {
        n.curState = Established implies n.connectedNode != none
    }

    // A nodes send buffer can only contain packets that have the node as the source
    all n: Node | {
        all pack : n.sendBuffer | {
            pack.src = n
        }
    }

    // A node's receive buffer can only contain packets that have the node as the destination
    all n: Node | {
        all pack: n.receiveBuffer | {
            pack.dst = n
        }
    }

    // If all nodes are closed, then the network should be empty
    (#{n : Node | n.curState = Closed} = #Node) implies {
        Network.packets = none
    }
}

// Predicate that ensures that all the nodes are "distinct" within the network
pred uniqueNodes {
    all disj n1, n2: Node | {
        n1.id != n2.id
    }
}

// The initial state of the system.
pred init {
    // all the nodes are unique
    uniqueNodes
    // All nodes are in closed state:
    all n: Node | {
        n.curState = Closed
    }
    // The network is empty:
    no Network.packets
    
    // All nodes should be empty, and not connected:
    all n: Node | {
        no n.receiveBuffer
        no n.sendBuffer
        n.connectedNode = none
    }
    
    all packet : Packet | {
        packet.src = none
        packet.dst = none
        packet.pSeqNum = none
        packet.pAckNum = none
    }
}

// This predicate is used to check if the two nodes are connected,
// and what constraints are needed to be satisfied for the connection to be valid.
pred Connected[node1: Node, node2: Node] {
    node1 != node2
    // The connection has been established.
    (node1.curState = Established and node2.curState = Established)

    // They are each other's receiver and sender.
    node1.connectedNode = node2
    node2.connectedNode = node1
}

// Predicate used to open a connection and maintain
// proper state transitions and constraints.
pred Open[sender, receiver: Node] {
    // Closed states must be maintained.
    sender.curState = Closed
    receiver.curState = Closed

    // The nodes cannot be connected to anything.
    no sender.connectedNode 
    no receiver.connectedNode
    // The nodes cannot have any packets in their buffers.
    no sender.receiveBuffer
    no sender.sendBuffer
    no receiver.receiveBuffer
    no receiver.sendBuffer

    // The sender will initiate a connection
    some i: Int | {
        i >= 0
        sender.curState' = SynSent
        sender.seqNum' = i // sender.ackNum' = 0
        sender.send_next' = add[i,1]
        sender.connectedNode' = receiver

        // We send the SYN packet to the receiver
        one packet: DataPacket | {
            packet.src' = sender
            packet.dst' = receiver
            packet.pSeqNum' = sender.seqNum'
            packet.pAckNum' = 0
            sender.sendBuffer' = sender.sendBuffer + packet

            all p: Packet - packet | {
                packetDoesNotChange[p]
            }
        }
    }

    nodeDoesNotChange[receiver]
    Network.packets' = Network.packets
}

// We send packet through an established connection.
pred userSend[sender: Node] {
    Connected[sender, sender.connectedNode]
    sender.seqNum' = sender.seqNum
    sender.ackNum' = sender.ackNum
    sender.send_next' = add[sender.send_next ,1]
    sender.receiveBuffer' = sender.receiveBuffer
    sender.connectedNode' = sender.connectedNode
    sender.recv_next' = sender.recv_next

    sender.curState' = sender.curState

    one packet: DataPacket | {
        packet.src' = sender
        packet.dst' = sender.connectedNode
        packet.pSeqNum' = sender.send_next'
        packet.pAckNum' = sender.recv_next'
        sender.sendBuffer' = sender.sendBuffer + packet
    }

    nodeDoesNotChange[sender.connectedNode]
    Network.packets' = Network.packets
}

// Predicate that moves packets from the sender's send buffer to the network.
pred Send[sender: Node] {
    (sender.curState != Closed) or (sender.curState = Closed and sender.connectedNode.curState = LastAck)
    #{sender.sendBuffer} > 0

    Network.packets' = Network.packets + sender.sendBuffer

    sender.curState' = sender.curState
    sender.seqNum' = sender.seqNum
    sender.ackNum' = sender.ackNum 
    sender.connectedNode' = sender.connectedNode
    sender.send_next' = sender.send_next
    sender.recv_next' = sender.recv_next
    sender.receiveBuffer' = sender.receiveBuffer
    no sender.sendBuffer'

    nodeDoesNotChange[sender.connectedNode]
    all p: Packet | {
        packetDoesNotChange[p]
    }
}

// Predicate that transfers packets from the network to the destination node's receive buffer.
pred Transfer {
    some packet: Network.packets | {
        let dest = packet.dst | {
            dest.receiveBuffer' = dest.receiveBuffer + packet
            Network.packets' = Network.packets - packet

            all n: Node - dest | nodeDoesNotChange[n]
            all p: Packet | packetDoesNotChange[p]

            dest.curState' = dest.curState
            dest.sendBuffer' = dest.sendBuffer
            dest.seqNum' = dest.seqNum
            dest.ackNum' = dest.ackNum
            dest.connectedNode' = dest.connectedNode
            dest.send_next' = dest.send_next
            dest.recv_next' = dest.recv_next
        }
    }
}

// Predicate for handling the constraints of receiving packets at different
// states of the algorithm.
pred Receive[node: Node] {
    Network.packets' = Network.packets
    some packet: node.receiveBuffer | {
        let srcNode = packet.src | {

            node.receiveBuffer' = node.receiveBuffer - packet

            // Closed state: Accept SYN and reply with SYN-ACK
            node.curState = Closed => {
                node.curState' = SynReceived
                node.connectedNode' = srcNode
                node.ackNum' = packet.pSeqNum
                node.recv_next' = add[packet.pSeqNum, 1]

                some i: Int | {
                    i >= 0
                    node.seqNum' = i
                    node.send_next' = add[i, 1]
                }

                one synAck: AckPacket | {
                    synAck.src' = node
                    synAck.dst' = srcNode
                    synAck.pSeqNum' = node.seqNum'
                    synAck.pAckNum' = node.recv_next'
                    node.sendBuffer' = node.sendBuffer + synAck

                    all p: Packet - synAck | {
                        packetDoesNotChange[p]
                    }
                }
            }

            // SynReceived state: Receive ACK -> Established
            else node.curState = SynReceived => {
                node.curState' = Established
                node.connectedNode' = node.connectedNode
                node.ackNum' = node.ackNum
                node.recv_next' = node.recv_next
                node.seqNum' = node.seqNum
                node.send_next' = node.send_next
                node.sendBuffer' = node.sendBuffer

                all p: Packet - packet | {
                    packetDoesNotChange[p]
                }
            }

            // SynSent state: Receive SYN-ACK -> Established, send final ACK
            else node.curState = SynSent => {
                node.curState' = Established
                node.ackNum' = packet.pSeqNum
                node.recv_next' = add[packet.pSeqNum, 1]
                node.connectedNode' = node.connectedNode
                node.seqNum' = node.seqNum
                node.send_next' = node.send_next

                one finalAck: AckPacket | {
                    finalAck.src' = node
                    finalAck.dst' = srcNode
                    finalAck.pSeqNum' = node.send_next'
                    finalAck.pAckNum' = node.recv_next'
                    node.sendBuffer' = node.sendBuffer + finalAck
                    all p: Packet - finalAck | {
                        packetDoesNotChange[p]
                    }
                }
            }

            // Established state: Process data, update recv_next and send ACK
            else (node.curState = Established and packet in DataPacket) => {
                node.curState' = node.curState
                node.connectedNode' = node.connectedNode
                node.ackNum' = node.ackNum
                node.seqNum' = node.seqNum
                node.send_next' = node.send_next

                // Only receive if in order
                node.recv_next' = add[packet.pSeqNum, 1]

                one dataAck: AckPacket | {
                    dataAck.src' = node
                    dataAck.dst' = srcNode
                    dataAck.pSeqNum' = node.send_next'
                    dataAck.pAckNum' = node.recv_next'
                    node.sendBuffer' = node.sendBuffer + dataAck

                    all p: Packet - dataAck | {
                        packetDoesNotChange[p]
                    }
                }
            }
            else (node.curState = LastAck and packet in AckPacket) => {
                becomeInit
            }
            else (packet in AckPacket) => {

                // node.curState' = node.curState
                node.curState = FinWait1 => {
                    node.curState' = FinWait2
                }  else (node.curState = Established) => {
                    node.curState' = node.curState
                }
                node.connectedNode' = node.connectedNode
                node.ackNum' = node.ackNum
                node.seqNum' = node.seqNum
                node.send_next' = node.send_next
                node.recv_next' = node.recv_next
                // node.receiveBuffer' = node.receiveBuffer
                node.sendBuffer' = node.sendBuffer

                // Not sure what we do here, throw it away?
                all p: Packet - packet | {
                    packetDoesNotChange[p]
                }
            }

            // first condition for closing
            else (node.curState = Established and packet in FinPacket) => {
                node.curState' = CloseWait
                // node.ackNum' = packet.pSeqNum
                node.recv_next' = add[packet.pSeqNum, 1]
                // node.connectedNode' = node.connectedNode
                node.ackNum' = node.ackNum
                node.seqNum' = node.seqNum
                node.send_next' = node.send_next
                // node.receiveBuffer' = node.receiveBuffer
                node.connectedNode' = node.connectedNode


                one ack: AckPacket | {
                    ack.src' = node
                    ack.dst' = srcNode
                    ack.pSeqNum' = node.send_next'
                    ack.pAckNum' = node.recv_next'
                    node.sendBuffer' = node.sendBuffer + ack
                    all p: Packet - ack | {
                        packetDoesNotChange[p]
                    }
                }       
            }

            // second condition for closing
            // else (node.curState = FinWait1 and packet in FinPacket) => {
            //     node.curState' = FinWait2
            //     node.ackNum' = node.ackNum
            //     // node.ackNum' = packet.pSeqNum
            //     node.recv_next' = add[packet.pSeqNum, 1]
            //     node.connectedNode' = node.connectedNode
            //     node.seqNum' = node.seqNum
            //     node.send_next' = node.send_next
            //     // node.receiveBuffer' = node.receiveBuffer
            //     node.sendBuffer' = node.sendBuffer
            //     all p: Packet | {
            //         packetDoesNotChange[p]
            //     }

            //     // one ack: AckPacket | {
            //     //     ack.src' = node
            //     //     ack.dst' = srcNode
            //     //     ack.pSeqNum' = node.send_next'
            //     //     ack.pAckNum' = node.recv_next'
            //     //     node.sendBuffer' = node.sendBuffer + ack
            //     //     all p: Packet - ack | {
            //     //         packetDoesNotChange[p]
            //     //     }
            //     // }                 
            // }

            else (node.curState = FinWait2 and packet in FinPacket) => {
                node.curState' = Closed
                node.ackNum' = node.ackNum
                // node.ackNum' = packet.pSeqNum
                node.recv_next' = add[packet.pSeqNum, 1]
                node.connectedNode' = node.connectedNode
                node.seqNum' = node.seqNum
                node.send_next' = node.send_next
                // node.receiveBuffer' = node.receiveBuffer
                // node.sendBuffer' = none

                one packet: AckPacket | {
                    packet.src' = node
                    packet.dst' = srcNode
                    packet.pSeqNum' = node.send_next'
                    packet.pAckNum' = node.recv_next'
                    node.sendBuffer' = node.sendBuffer + packet

                    all p: Packet - packet | {
                        packetDoesNotChange[p]
                    }
                }
            }

            // Frame conditions for all other nodes and packets
            node.curState != LastAck => {
                all n: Node - node | nodeDoesNotChange[n]
            } 
        }
    }
}

pred Close[sender, receiver: Node] {
    // They must both be established and connected:
    // Connected[sender, receiver]
    no Network.packets
    no sender.receiveBuffer
    no receiver.receiveBuffer
    no sender.sendBuffer
    no receiver.sendBuffer

    Network.packets' = Network.packets
    sender.connectedNode' = sender.connectedNode
    sender.seqNum' = sender.seqNum
    sender.ackNum' = sender.ackNum
    sender.send_next' = sender.send_next
    sender.recv_next' = sender.recv_next
    sender.receiveBuffer' = sender.receiveBuffer
    nodeDoesNotChange[receiver]

    receiver.curState = Established or receiver.curState = FinWait2
    sender.curState = Established or sender.curState = CloseWait

    sender.curState = Established => {
        one packet: FinPacket | {
            packet.src' = sender
            packet.dst' = receiver
            packet.pSeqNum' = sender.send_next'
            packet.pAckNum' = sender.recv_next'
            sender.sendBuffer' = sender.sendBuffer + packet

            all p: Packet - packet | {
                packetDoesNotChange[p]
            }
        }
        sender.curState' = FinWait1
    } else sender.curState = CloseWait => {
        one packet: FinPacket | {
            packet.src' = sender
            packet.dst' = receiver
            packet.pSeqNum' = sender.send_next'
            packet.pAckNum' = sender.recv_next'
            sender.sendBuffer' = sender.sendBuffer + packet

            all p: Packet - packet | {
                packetDoesNotChange[p]
            }
        }
        sender.curState' = LastAck
    }
}

// Pred that turns the states back into the init state, allowing for a lasso trace.
pred becomeInit {
    uniqueNodes
    // All nodes are in closed state:
    all n: Node | {
        n.curState' = Closed
    }
    // The network is empty:
    no Network.packets'
    
    // All nodes should be empty, and not connected:
    all n: Node | {
        no n.receiveBuffer'
        no n.sendBuffer'
        n.connectedNode' = none
    }
    
    all packet : Packet | {
        packet.src' = none
        packet.dst' = none
        packet.pSeqNum' = none
        packet.pAckNum' = none
    }
}

// Defines the valid moves that the nodes can do
pred moves[sender, receiver: Node]{
    Open[sender, receiver] or
    Send[sender] or
    Transfer or
    Receive[receiver] or
    Receive[sender] or
    Send[receiver] or
    Close[sender, receiver] or
    Close[receiver, sender] or
    userSend[sender] or
    userSend[receiver]

    all n: Node | {
        some n.sendBuffer => eventually Send[n]
        some n.receiveBuffer => eventually Receive[n]
    }

    some Network.packets => eventually Transfer
}

pred doNothing {
    all n: Node | {
        nodeDoesNotChange[n]
    }
    all p: Packet | {
        packetDoesNotChange[p]
    }
    Network.packets' = Network.packets
}

pred traces {
    init
    always {validState}
    some disj sender, receiver: Node | {
        eventually Open[sender, receiver]
        eventually Send[sender]
        eventually Transfer
        eventually Connected[sender, receiver]
        eventually Receive[receiver]
        eventually userSend[sender]

        always moves[sender, receiver]
        eventually Close[sender, receiver]
        eventually Close[receiver, sender]
    }
}

pred traces2 {
    always {validState}
    some disj sender, receiver: Node | {
        Connected[sender, receiver]
        no sender.receiveBuffer
        no receiver.receiveBuffer
        no sender.sendBuffer
        no receiver.sendBuffer
        no Network.packets
        always moves[sender, receiver]
        eventually Close[sender, receiver]
        eventually Close[receiver, sender]
    }
}

run {
    traces
} for exactly 2 Node, exactly 4 Packet
