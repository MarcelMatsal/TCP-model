#lang forge/temporal

---------- Definitions ----------

abstract sig State {}

sig Closed extends State {}
sig SynReceived extends State {}
sig SynSent extends State {}
sig Established extends State {}
sig FinWait1 extends State {}
sig FinWait2 extends State {}
sig TimeWait extends State {}
sig CloseWait extends State {}

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
    var send_una: one Int,
    var send_lbw: one Int,

    var recv_next: one Int,
    var recv_lbr: one Int
}

// A packet in the system.
sig Packet {
    src: one Node,
    dst: one Node,
    pSeqNum: one Int,
    pAckNum: one Int
}

// The network of the system (holding in-transit packets).
one sig Network {
    var packets: set Packet
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
        p.src != p.dst
    }

    // Any node with a connected node has to be connected back:
    all n: Node | {
        n.curState = Established implies n.connectedNode != none
        (n.curState = Established implies {
            n.connectedNode.connectedNode = n
        })
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

    // If all nodes are closed, then the network should be empty
    all n: Node | {
        n.curState = Closed implies Network.packets = none
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
    some i : Int | {
        i >= 0
        sender.curState' = SynSent
        sender.seqNum' = i // sender.ackNum' = 0
        sender.send_next' = i + 1
        sender.connectedNode' = receiver

        // We send the SYN packet to the receiver
        one packet: Packet | {
            packet.src = sender
            packet.dst = receiver
            packet.pSeqNum = sender.seqNum'
            packet.pAckNum = 0
            sender.sendBuffer' = packet
        }
    }

    receiver.curState' = receiver.curState
    receiver.connectedNode' = receiver.connectedNode
    receiver.seqNum' = receiver.seqNum
    receiver.ackNum' = receiver.ackNum
    receiver.send_next' = receiver.send_next
    receiver.recv_next' = receiver.recv_next
    // receiver.send_una' = receiver.send_una
    // receiver.send_lbw' = receiver.send_lbw
    // receiver.recv_lbr' = receiver.recv_lbr
}

// We send packet through a connection.
pred userSend[sender: Node] {
    // I Think that this should add things to a sendbuffer (for later retransmission),
    // but at this point, just dump all the packets into the network. Right?

    sender.curState = Established
    sender.seqNum' = sender.seqNum + 1
    sender.ackNum' = sender.ackNum
    sender.send_lbw' = sender.send_lbw + 1

    one packet: Packet | {
        packet.src = sender
        packet.dst = sender.connectedNode
        packet.pSeqNum = sender.seqNum'
        packet.pAckNum = sender.ackNum'
        sender.sendBuffer' = sender.sendBuffer + packet
    }
}

pred send[sender: Node] {
    all packet: sender.sendBuffer | {
        Network.packets' = Network.packets + packet
        // not sure if this works?
        // this would only work if there is only One packet within the sendBuffer I think
        sender.send_next' = packet.pSeqNum
    }
    #{sender.sendBuffer'} = 0
}

// Predicate that transfers packets from the network to the destination node's receive buffer.
pred Transfer {
    all packet: Packet | {
        packet in Network.packets => {
            // They must be connected.
            Connected[packet.src, packet.dst]
            packet.dst.receiveBuffer' = packet.dst.receiveBuffer + packet
        }
    }
    #{Network.packets'} = 0
}

pred Receive [node: Node] {
    all packet: node.receiveBuffer | {
        // closed -> make sure the packet is a syn packet
        // go into syn received state
        // send second step of handshake
        node.curState = Closed implies {
            node.curState' = SynReceived
            node.recv_next' = packet.pSeqNum + 1
            node.ackNum' = packet.pSeqNum
            
            node.connectedNode' = packet.src

            some i : Int | {
                i >= 0
                node.seqNum' = i
                node.send_next' = i + 1
            }

            // send back a syn ack packet
            one ackPacket: Packet | {
                ackPacket.src = node
                ackPacket.dst = packet.src
                ackPacket.pSeqNum = node.seqNum'
                ackPacket.pAckNum = node.recv_next'
                node.sendBuffer' = node.sendBuffer + ackPacket
            }
        }
        

        // syn received -> go into established state

        node.curState = SynReceived implies {
            node.curState' = Established
            // node.recv_next' = packet.pSeqNum + 1
            // node.ackNum' = packet.pSeqNum
        }

        // syn sent -> send back last part of handshake
        // go into established state

        node.curState = SynSent implies {
            node.curState' = Established
            node.ackNum' = packet.pSeqNum
            node.recv_next' = packet.pSeqNum + 1

            one ackPacket: Packet | {
                ackPacket.src = node
                ackPacket.dst = packet.src
                ackPacket.pSeqNum = node.send_next'
                ackPacket.pAckNum = node.recv_next'
                node.sendBuffer' = node.sendBuffer + ackPacket
            }
        }

        // established
        //  make sure packet has ack flag
        //  if ack is > send_una and <= send_next
        //    update send_una (the last byte that has been acked)
        //  if seq <= rcv_next
        //    receive data
        //    increment rcv_next (next byte to be received)
        // send back ack (send_next, rcv_next)

        node.curState = Established implies {
            // node.curState' = Established
            // node.ackNum' = packet.pSeqNum
            // node.recv_next' = packet.pSeqNum + 1

            // if packet.pAckNum > node.send_una and packet.pAckNum <= node.send_next
            //     node.send_una' = packet.pAckNum

            // if packet.pSeqNum <= node.recv_next
            //     node.receiveBuffer' = node.receiveBuffer + packet
            //     node.recv_next' = packet.pSeqNum + 1


            node.recv_next' = packet.pSeqNum + 1

            one ackPacket: Packet | {
                ackPacket.src = node
                ackPacket.dst = packet.src
                ackPacket.pSeqNum = node.send_next'
                ackPacket.pAckNum = node.recv_next'
                node.sendBuffer' = node.sendBuffer + ackPacket
            }
        }
    }
}

pred Close[sender, receiver: Node] {
    // They must both be established and connected:
    Connected[sender, receiver]

    // The sender will initiate the close connection.
    one packet: Packet | {
        packet.src = sender
        packet.dst = receiver
        packet.pSeqNum = sender.seqNum + 1
        packet.pAckNum = sender.ackNum
        sender.sendBuffer' = sender.sendBuffer + packet

        // The sender will go into the FinWait1 state.
        sender.curState' = FinWait1 // Is this weird because it will never actually happen?
    }

    one ackPacket: Packet | {
        ackPacket.src = receiver
        ackPacket.dst = sender
        ackPacket.pSeqNum = receiver.seqNum + 1
        ackPacket.pAckNum = sender.seqNum + 1
        receiver.sendBuffer' = receiver.sendBuffer + ackPacket

        // The receiver will go into the CloseWait state.
        receiver.curState' = CloseWait // Is this weird because it will never actually happen?
    }

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


// defines the valid moves that the nodes can do
pred moves[sender, receiver: Node]{
    // I am thinking this should be kinda like a bunch of implications based on the current states of the nodes
    ((sender.curState = Closed and receiver.curState = Closed) implies Open[sender, receiver]) 
    
    // should be an OR of the possible moves
    // doNothing for Lasso?

}

pred doNothing {
    // predicate that allows for lasso traces and has the model do nothin 
    all n: Node | {
        n.curState' = n.curState
        n.receiveBuffer' = n.receiveBuffer
        n.sendBuffer' =  n.sendBuffer
        n.seqNum' = n.seqNum
        n.ackNum' = n.ackNum
        n.connectedNode' = n.connectedNode
        n.send_next' =  n.send_next
        n.send_una' = n.send_una
        n.send_lbw' = n.send_lbw
        n.recv_next' = n.recv_next
        n.recv_lbr' = n.recv_lbr
    }
}

pred traces {
    init
    all disj sender, receiver: Node | {
        always {
            validState
            moves[sender,receiver]
        }
    }


}

run {
    traces
} for exactly 2 Node, 4 Packet

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





















