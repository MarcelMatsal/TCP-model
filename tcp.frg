#lang forge/temporal

option max_tracelength 30
option min_tracelength 19

option solver Glucose

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
    // var send_una: one Int,
    // var send_lbw: one Int,

    var recv_next: one Int
    // var recv_lbr: one Int
}

// A packet in the system.
sig Packet {
    var src: lone Node,
    var dst: lone Node,
    var pSeqNum: lone Int,
    var pAckNum: lone Int
}

// The network of the system (holding in-transit packets).
one sig Network {
    var packets: set Packet
}

pred nodeDoesNotChange[n: Node] {
    n.curState' = n.curState
    n.receiveBuffer' = n.receiveBuffer
    n.sendBuffer' = n.sendBuffer
    n.seqNum' = n.seqNum
    n.ackNum' = n.ackNum
    n.connectedNode' = n.connectedNode
    n.send_next' = n.send_next
    // n.send_una' = n.send_una
    // n.send_lbw' = n.send_lbw
    n.recv_next' = n.recv_next
    // n.recv_lbr' = n.recv_lbr
}

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

    // Any node with a connected node has to be connected back:
    all n: Node | {
        n.curState = Established implies n.connectedNode != none
        n.curState = Established implies n.connectedNode.connectedNode = n
        // should we have something like 
        //(n.curState = Established implies {n.connectedNode != n})
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

    // CONFLICTS WITH OPEN SINCE RECEIVER IS STILL CLOSED
    // If all nodes are closed, then the network should be empty
    // all n: Node | {
    //     n.curState = Closed implies Network.packets = none
    // }

    // Packet values shouldn't change
    all p: Packet | {
        p.pSeqNum != none implies (p.pSeqNum' = p.pSeqNum)
        p.pAckNum != none implies (p.pAckNum' = p.pAckNum)
        p.src != none implies (p.src' = p.src)
        p.dst != none implies (p.dst' = p.dst)
    }
}

pred uniqueNodes {
    // predicate that ensures that all the nodes are "distinct" within the netword
    all disj n1, n2: Node | {
        n1.id != n2.id
    }
}

pred connectionMaintainedUntilClosed[sender, receiver: Node] {
    // the sender and receiver will stay connected to eachother until the connection is closed
    sender.connectedNode = receiver until {sender.curState = Closed}
    receiver.connectedNode = sender until {receiver.curState = Closed}
  
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
    Network.packets = none
    
    // All nodes should be empty, and not connected:
    all n: Node | {
        n.receiveBuffer = none
        n.sendBuffer = none
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
        sender.send_next' = i + 1
        sender.connectedNode' = receiver

        // We send the SYN packet to the receiver
        one packet: Packet | {
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

    // receiver.curState' = receiver.curState
    // // receiver.connectedNode' = sender
    // reciever.connectedNode' = receiver.connectedNode
    // receiver.seqNum' = receiver.seqNum
    // receiver.ackNum' = receiver.ackNum
    // receiver.send_next' = receiver.send_next
    // receiver.recv_next' = receiver.recv_next
    // receiver.sendBuffer' = receiver.sendBuffer
    // receiver.receiveBuffer' = receiver.receiveBuffer
    // receiver.send_una' = receiver.send_una
    // receiver.send_lbw' = receiver.send_lbw
    // receiver.recv_lbr' = receiver.recv_lbr

    // eventually Send[sender]
}

// We send packet through a connection.
pred userSend[sender: Node] {
    // I Think that this should add things to a sendbuffer (for later retransmission),
    // but at this point, just dump all the packets into the network. Right?

    Connected[sender, sender.connectedNode]

    sender.seqNum' = sender.seqNum
    sender.ackNum' = sender.ackNum
    // sender.send_lbw' = sender.send_lbw + 1
    sender.send_next' = sender.send_next + 1
    sender.receiveBuffer' = sender.receiveBuffer
    sender.connectedNode' = sender.connectedNode
    sender.recv_next' = sender.recv_next

    sender.curState' = sender.curState

    one packet: Packet | {
        packet.src' = sender
        packet.dst' = sender.connectedNode
        packet.pSeqNum' = sender.send_next'
        packet.pAckNum' = sender.recv_next'
        sender.sendBuffer' = sender.sendBuffer + packet
    }

    nodeDoesNotChange[sender.connectedNode]
    Network.packets' = Network.packets

    eventually Send[sender]
}

pred Send[sender: Node] {
    sender.curState != Closed
    #{sender.sendBuffer} > 0
    // all packet: sender.sendBuffer | {
    //     Network.packets' = Network.packets + packet
    //     // not sure if this works?
    //     // this would only work if there is only One packet within the sendBuffer I think
    //     // sender.send_next' = packet.pSeqNum
    // }
    Network.packets' = Network.packets + sender.sendBuffer

    sender.curState' = sender.curState
    sender.seqNum' = sender.seqNum
    sender.ackNum' = sender.ackNum 
    sender.connectedNode' = sender.connectedNode
    sender.send_next' = sender.send_next
    sender.recv_next' = sender.recv_next
    sender.receiveBuffer' = sender.receiveBuffer
    sender.sendBuffer' = none

    // nodeDoesNotChange[sender]
    nodeDoesNotChange[sender.connectedNode]
    
    all p: Packet | {
        packetDoesNotChange[p]
    }
    // eventually Transfer
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


            // eventually Receive[dest]
        }
    }
}

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
                node.recv_next' = packet.pSeqNum + 1

                some i: Int | {
                    i >= 0
                    node.seqNum' = i
                    node.send_next' = i + 1
                }

                one synAck: Packet | {
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
            }

            // SynSent state: Receive SYN-ACK -> Established, send final ACK
            else node.curState = SynSent => {
                node.curState' = Established
                node.ackNum' = packet.pSeqNum
                node.recv_next' = packet.pSeqNum + 1
                node.connectedNode' = node.connectedNode
                node.seqNum' = node.seqNum
                node.send_next' = node.send_next

                one finalAck: Packet | {
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
            else node.curState = Established => {
                // Only receive if in order
                node.recv_next' = packet.pSeqNum + 1

                one dataAck: Packet | {
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

            // Frame conditions for all other nodes and packets
            all n: Node - node | nodeDoesNotChange[n]
        }
    }
}

pred Close[sender, receiver: Node] {
    // They must both be established and connected:
    Connected[sender, receiver]
    no Network.packets
    // no sender.receiveBuffer
    no receiver.receiveBuffer
    no sender.sendBuffer
    // no receiver.sendBuffer

    // The sender will initiate the close connection.
    // one packet: Packet | {
    //     packet.src = sender
    //     packet.dst = receiver
    //     packet.pSeqNum = sender.seqNum + 1
    //     packet.pAckNum = sender.ackNum
    //     sender.sendBuffer' = sender.sendBuffer + packet

    //     // The sender will go into the FinWait1 state.
    //     sender.curState' = FinWait1 // Is this weird because it will never actually happen?
    // }

    // one ackPacket: Packet | {
    //     ackPacket.src = receiver
    //     ackPacket.dst = sender
    //     ackPacket.pSeqNum = receiver.seqNum + 1
    //     ackPacket.pAckNum = sender.seqNum + 1
    //     receiver.sendBuffer' = receiver.sendBuffer + ackPacket

    //     // The receiver will go into the CloseWait state.
    //     receiver.curState' = CloseWait // Is this weird because it will never actually happen?
    // }

    // Connected[sender, receiver]

    // They are both closed:
    sender.curState' = Closed
    receiver.curState' = Closed
    // They are not connected to anything:
    sender.connectedNode' = none
    receiver.connectedNode' = none
    // They have no packets in their buffers:
    sender.receiveBuffer' = none
    sender.sendBuffer' = none
    receiver.receiveBuffer' = none
    receiver.sendBuffer' = none
}

pred dummyClose {
    // This is a dummy close that does not actually do anything
    // It is used to allow for lasso traces
    all n: Node | {
        n.curState = Closed
        n.receiveBuffer = none
        n.sendBuffer = none
        n.connectedNode = none
    }
    // all p: Packet | {
    //     p.src = none
    //     p.dst = none
    //     p.pSeqNum = none
    //     p.pAckNum = none
    // }
    Network.packets = none
}


// defines the valid moves that the nodes can do
pred moves[sender, receiver: Node]{
    Open[sender, receiver] or
    // Receive[receiver] or 
    // Transfer or 
    Send[sender] or
    Transfer or
    Receive[receiver] or
    Receive[sender] or
    Send[receiver] or
    Close[sender, receiver] or
    userSend[sender] or
    userSend[receiver]
    or doNothing

    all n: Node | {
        some n.sendBuffer => eventually Send[n]
    }
    // all n: Node | {
    //     some n.receiveBuffer => eventually Receive[n]
    // }
    some Network.packets => eventually Transfer
    // // I am thinking this should be kinda like a bunch of implications based on the current states of the nodes
    // ((sender.curState = Closed and receiver.curState = Closed) implies Open[sender, receiver]) 
    
    // // should be an OR of the possible moves
    // // doNothing for Lasso?

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
        eventually Receive[receiver]
        always moves[sender, receiver]
        // eventually dummyClose
        eventually Connected[sender, receiver]
        eventually Close[sender, receiver]
        eventually userSend[sender]
    }
}

run {
    traces
} for exactly 2 Node, exactly 4 Packet

pred senderAndReceiver[n1, n2: Node]{
    // temporally the sneder and the reciever should only be one and they should not change roles throughout the trace
    always {
        // one should be the sender and the other should not be
        isSender[n1] or isSender[n2]
        not (isSender[n1] and isSender[n2])
        // one should be the receiveer and the other should not be
        isReceiver[n1] or isReceiver[n2]
        not (isReceiver[n1] and isReceiver[n2])

        // if one is the sender the other should be the receiver
        isSender[n1] implies {
            isReceiver[n2]
            // these roles should hold throughout time
            next_state isReceiver[n2]
            next_state isSender[n1]
             }
        isSender[n2] implies {
            isReceiver[n1]
            // these roles should hold throughout time
            next_state isReceiver[n1]
            next_state isSender[n2]
            }
    }
}


pred isSender[n: Node] {
    // predicate that defines a node to be the one that sends the data

    



}

pred isReceiver[n: Node] {
    // predicate that defines a node to be the one that recieves the data




}


// THESE possible actions should check some sort of action/boolean to make sure they can occur

// run BasicTrace: {
//     // things that constrain the runs and ensure validity
//     init
//     validState
//     // things that constrain the actions that happen
//     always {
//         all disj n1, n2: Node | {

//             // one of them must be the sender and the other the receiver
//             senderAndReceiver[n1,n2]

//             // possible actions to take
//             // three step handshake, send info or close connection
//             threeStepHandshake[n1, n2] or sendInfo[n1, n2] or closeConnection[n1, n2] or doNothing

//             // if a connection is ever opened then it must close eventually
//             // (connectionOpened could be like a flag)
//             (connectionOpened[n1] and connectionOpened[n2]) implies eventually {closeConnection[n1, n2]}
//         }
//     }
// } for 2 Node




// run {
//     // traces for ...
// }