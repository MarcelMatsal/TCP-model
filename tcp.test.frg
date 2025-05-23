#lang forge/temporal

open "tcp.frg"


/* Testing suite for the TCP Model.

Here we test the different predicates that our model has, how things intereact, the system as a whole and 
properties of the overall system. 

*/

/* PREDICATE TESTS */


test suite for validState {
    // SAT CASES
    // a connected node has something pointed to it and it points back to that
    test expect {
        twoWayConnections: {
            validState
            some disj n,n2: Node | {
                n.seqNum = 1
                n2.seqNum = 2
                n.curState = Established
                n2.curState = Established
                n.connectedNode = n2 implies n2.connectedNode = n
            }
        } is sat
    }

    // being Established means you have a connection
    test expect {
        establishedMeansConnect: {
            validState
            some disj n,n2: Node | {
                n.seqNum = 1
                n2.seqNum = 2
                n.curState = Established
                n2.curState = Established
                some n.connectedNode
                some n2.connectedNode
            }
        } is sat
    }


    // UNSAT CASES
    // case sequence number of some node is not valid
    test expect {
  
        badSequenceNumberOne: {
            validState
            some n: Node | {
                n.seqNum = -1
            }
        } is unsat
    }

    // case that packet has the same dest and src
    test expect {
        badSrcAndDest: {
            validState
            some p: Packet | {
                some n: Node | {
                    p.src = n
                    p.dst = n
                }
            }
        } is unsat
    }

    // a node points to another but one is not Established or pointing to the other
    test expect {
            mustBeEstablished: {
            validState
            some disj n,n2: Node | {
                n.seqNum = 1
                n2.seqNum = 2
                n.curState = Established
                n2.curState = Closed
                n.connectedNode = n2
                no n2.connectedNode
            }
        } is sat
    }
    
    // a send buffer contains packets with other node as the source
    test expect {
            sendBufferNodes: {
            validState
            some disj n,n2: Node | {
                n.seqNum = 1
                n2.seqNum = 2
                some pack: n.sendBuffer | {
                    pack.src = n2
                }
            }
        } is unsat
    }

    // a receive buffer contains packets with other node as the destination
    test expect {
            receiveBufferNodes: {
            validState
            some disj n,n2: Node | {
                n.seqNum = 1
                n2.seqNum = 2
                some pack: n.receiveBuffer | {
                    pack.dst = n2
                }
            }
        } is unsat
    }

    // all nodes are closed but the network is not empty
    test expect {
            closedButNotEmpty: {
            validState
            all n: Node| {
                n.curState = Closed
            }
            #{Network.packets} > 0
        } is unsat
    }
}

test suite for uniqueNodes {
    // all nodes have diff ids
    test expect {
            diffIds: {
            uniqueNodes
            all n, n2: Node| {
                n != n2 implies n.id != n2.id
            }
        } is sat
    }

    // some diff nodes have the same id
    test expect {
            notUnique: {
            uniqueNodes
            some disj n,n2: Node | {
                n.id = n2.id
            }
        } is unsat
    }
}

test suite for Connected {

    // SAT CASES
    
    // they are connected to eachother
    test expect {
        twoWayConnection: {
            all disj n1, n2: Node | {
                Connected[n1, n1] implies {
                    n1.connectedNode = n2
                    n2.connectedNode = n1
                }
            }
        } is sat
    } 

    test expect {
        twoWayConnection2: {
            all disj n1, n2: Node | {
                Connected[n1, n1]
                n1.connectedNode = n2
                n2.connectedNode = n1
            }
        } is sat
    } 
    // they are both established
    test expect {
        establishedNeeded: {
            all disj n1, n2: Node | {
                Connected[n1, n1] implies {
                    n1.curState = Established
                    n2.curState = Established             
                }

            }
        } is sat
    } 

    test expect {
        establishedNeeded2: {
            all disj n1, n2: Node | {
                Connected[n1, n1]
                n1.curState = Established
                n2.curState = Established             
            }
        } is sat
    } 


    // UNSAT CASES
    // same node connected to itself
    test expect {
        selfConnection: {
            some n1: Node | {
                Connected[n1, n1]
                n1.curState = Established
            }
        } is unsat
    } 
    // the connections are not established
    test expect {
        establishedConnectionsNeeded: {
            some n1, n2: Node | {
                Connected[n1, n1]
                n1.curState = Established
                n2.curState = Closed
            }
        } is unsat
    } 

    test expect {
        establishedConnectionsNeeded2: {
            some n1, n2: Node | {
                Connected[n1, n1]
                n1.curState = FinWait1
                n2.curState = Established
            }
        } is unsat
    } 

    // they are not each others sender or receiver

}

test suite for init {

    // SAT CASES

    // all the nodes must be unique
    assert uniqueNodes is necessary for init

    // all nodes are empty and disconnected
    test expect {
        cleanNodes: {
            init
            all n: Node | {
                #{n.receiveBuffer} = 0
                #{n.sendBuffer} = 0
                #{n.connectedNode} = 0
            }
        } is sat
    } 
    // network is empty
    test expect {
        cleanNetwork: {
            init
            #{Network.packets} = 0
        } is sat
    } 

    // all nodes are closed
    test expect {
        allClosed: {
            init
            all n: Node| {
                n.curState = Closed
            }
        } is sat
    } 

    // UNSAT CASES
}


test suite for Open {

    // SAT CASES
    // making sure the prestates are correct
    test expect {
        validPrestates: {
            all disj n1, n2: Node | {
                Open[n1,n2]
                n1.curState = Closed
                n2.curState = Closed
                no n1.connectedNode
                no n2.connectedNode
                // The nodes cannot have any packets in their buffers.
                no n1.receiveBuffer
                no n2.sendBuffer
                no n1.receiveBuffer
                no n1.sendBuffer
            }
        } is sat
    } 
    // making sure the poststates are correct
    test expect {
        validPostStates: {
            all disj n1, n2: Node | {
                Open[n1,n2] implies {
                    some packet: Packet | {
                        packet.src = n1
                        packet.dst = n2
                        packet.pSeqNum = n1.seqNum'
                        packet.pAckNum = n1.ackNum'
                        n1.sendBuffer' = packet
                    }
                    n1.connectedNode' = n2
                    n1.curState' = SynSent
                    n1.ackNum' = 0
                }
            }
        } is sat
    } 
    // making sure they are connected
     test expect {
        validConnectionCreated: {
            all disj n1, n2: Node | {
                Open[n1,n2] implies {
                    n1.connectedNode' = n2
                    n2.connectedNode' = n1
                }
            }
        } is sat
    }    
    test expect {
        validConnectionCreated2: {
            all disj n1, n2: Node | {
                Open[n1,n2] implies {
                    n2.connectedNode' = n1
                }
            }
        } is sat
    }    


    // UNSAT CASES
    // there is something in the buffers before
    test expect {
        invalidPreBuffer: {
            some disj n1, n2: Node | {
                Open[n1,n2]
                n1.curState = Closed
                n2.curState = Closed
                no n1.connectedNode
                no n2.connectedNode
                // The nodes cannot have any packets in their buffers.
                some p: Packet | {
                    p in n1.receiveBuffer
                }
                no n2.sendBuffer
                no n1.receiveBuffer
                no n1.sendBuffer
            }
        } is unsat
    } 
    test expect {
        invalidPreBuffer2: {
            some disj n1, n2: Node | {
                Open[n1,n2]
                n1.curState = Closed
                n2.curState = Closed
                no n1.connectedNode
                no n2.connectedNode
                // The nodes cannot have any packets in their buffers.
                some p: Packet | {
                    p in n2.sendBuffer
                }
                no n1.receiveBuffer
                no n1.sendBuffer
            }
        } is unsat
    }
    test expect {
        invalidPreBuffer3: {
            some disj n1, n2: Node | {
                Open[n1,n2]
                n1.curState = Closed
                n2.curState = Closed
                no n1.connectedNode
                no n2.connectedNode
                // The nodes cannot have any packets in their buffers.
                some p: Packet | {
                    p in n1.sendBuffer
                }
                no n1.receiveBuffer
                no n2.sendBuffer
            }
        } is unsat
    }  

    // invalid prestate (not closed)
    test expect {
        invalidPrestate: {
            validState
            some disj n1, n2: Node | {
                n1.curState != Closed
                n2.curState = Closed
                Open[n1,n2]
                no n1.connectedNode
                no n2.connectedNode
                no n1.receiveBuffer
                no n2.sendBuffer
                no n1.receiveBuffer
                no n1.sendBuffer
            }
        } is unsat
    } 
    test expect {
        invalidPrestate2: {
            validState
            some disj n1, n2: Node | {
                n1.curState = Closed
                n2.curState != Closed
                Open[n1,n2]
                no n1.connectedNode
                no n2.connectedNode
                no n1.receiveBuffer
                no n2.sendBuffer
                no n1.receiveBuffer
                no n1.sendBuffer
            }
        } is unsat
    } 
}


test suite for userSend {

    // SAT TESTS

    // checking to make sure that it can use radom valid values for its prestates
    test expect {
        validUSendPre: {
            all sender: Node | {
                sender.seqNum = 2
                sender.ackNum = 0
                // sender.send_lbw = 1
                userSend[sender]
                sender.curState = Established
            }
        } is sat
    }  

    // checking to make sure values get correctly added to the proper amount
    test expect {
        validUSendPost: {
            all sender: Node | {
                sender.seqNum = 2
                sender.ackNum = 0
                // sender.send_lbw = 1
                userSend[sender]
                sender.curState = Established
                sender.seqNum' = 3
                sender.ackNum' = 0
                // sender.send_lbw' = 2
            }
        } is sat
    }  

    // checking to make sure packet generated properly
    test expect {
        validPacketFill: {
            all sender: Node | {
                sender.seqNum = 2
                sender.ackNum = 0
                // sender.send_lbw = 1
                userSend[sender]
                sender.curState = Established
                sender.seqNum' = 3
                sender.ackNum' = 0
                // sender.send_lbw' = 2
                some p: Packet | {
                    p.src = sender
                    p.dst = sender.connectedNode
                    p.pSeqNum = 3
                    p.pAckNum = 0
                    sender.sendBuffer' = sender.sendBuffer + p
                }
            }
        } is sat
    }

    // size of send buffer should grow
    test expect {
        validPacketFill2: {
            all sender: Node | {
                userSend[sender]
                #{sender.sendBuffer'} > #{sender.sendBuffer}
            }
        } is sat
    }

    // UNSAT TESTS

    // size of the send buffer decreases
    test expect {
        invalidSendBuffer: {
            some sender: Node | {
                userSend[sender]
                #{sender.sendBuffer'} < #{sender.sendBuffer}
            }
        } is unsat
    }  

    // sender was not established beforehand
    test expect {
        invalidUSendState: {
            some sender: Node | {
                userSend[sender]
                sender.curState != Established
            }
        } is unsat
    }  

    // the math for the pre and post states is wrong
    test expect {
        wrongMath: {
            some sender: Node | {
                sender.seqNum = 2
                sender.ackNum = 0
                sender.send_next = 2
                // sender.send_lbw = 1
                userSend[sender]
                sender.curState = Established
                sender.send_next' = 2
                sender.seqNum' = 2
                sender.ackNum' = 0
                // sender.send_lbw' = 2
            }
        } is unsat
    } 

    test expect {
        wrongMath2: {
            some sender: Node | {
                sender.seqNum = 2
                sender.ackNum = 0
                // sender.send_lbw = 1
                userSend[sender]
                sender.curState = Established
                sender.seqNum' = 3
                sender.ackNum' != 0
                // sender.send_lbw' = 2
            }
        } is unsat
    }  
    test expect {
        wrongMath3: {
            some sender: Node | {
                sender.seqNum = 2
                sender.ackNum = 0
                // sender.send_lbw = 1
                userSend[sender]
                sender.curState = Established
                sender.seqNum' = 3
                sender.ackNum' = 0
                // sender.send_lbw' = 4
            }
        } is unsat
    }   

    // incorrect packet setup

    // source of packet is not the sender
    test expect {
        invalidPacketFill: {
            some sender: Node | {
                sender.seqNum = 2
                sender.ackNum = 0
                // sender.send_lbw = 1
                userSend[sender]
                sender.curState = Established
                sender.seqNum' = 3
                sender.ackNum' = 0
                // sender.send_lbw' = 2
                one p: Packet | {
                    some n2: Node | {
                        n2 != sender
                        p.src = n2
                    }
                    p.dst = sender.connectedNode
                    p.pSeqNum = 3
                    p.pAckNum = 0
                    sender.sendBuffer' = sender.sendBuffer + p
                }
            }
        } is unsat
    }
    // wrong destination for the packet
    test expect {
        invalidPacket2: {
            some sender: Node | {
                sender.seqNum = 2
                sender.ackNum = 0
                // sender.send_lbw = 1
                userSend[sender]
                sender.curState = Established
                sender.seqNum' = 3
                sender.ackNum' = 0
                // sender.send_lbw' = 2
                one p: Packet | {
                    some n2: Node | {
                        n2 != sender
                        p.dst = n2.connectedNode
                    }
                    p.src = sender
                    p.pSeqNum = 3
                    p.pAckNum = 0
                    sender.sendBuffer' = sender.sendBuffer + p
                }
            }
        } is unsat
    }  
    // wrong buffer 
    test expect {
        invalidPacket3: {
            some sender: Node | {
                sender.seqNum = 2
                sender.ackNum = 0
                // sender.send_lbw = 1
                userSend[sender]
                sender.curState = Established
                sender.seqNum' = 3
                sender.ackNum' = 0
                // sender.send_lbw' = 2
                one p: Packet | {
                    some n2: Node | {
                        n2 != sender
                        sender.sendBuffer' = n2.sendBuffer + p
                    }
                    p.dst = sender.connectedNode
                    p.src = sender
                    p.pSeqNum = 3
                    p.pAckNum = 0
                }
            }
        } is unsat
    }   

    // wrong numbers
    test expect {
        invalidPacket4: {
            some sender: Node | {
                sender.seqNum = 2
                sender.ackNum = 0
                // sender.send_lbw = 1
                userSend[sender]
                sender.curState = Established
                sender.seqNum' = 3
                sender.ackNum' = 0
                // sender.send_lbw' = 2
                one p: Packet | {
                    p.dst = sender.connectedNode
                    p.src = sender
                    sender.sendBuffer' = sender.sendBuffer + p
                    p.pSeqNum != 3
                    p.pAckNum = 0
                }
            }
        } is unsat
    }  
    test expect {
        invalidPacket5: {
            some sender: Node | {
                sender.seqNum = 2
                sender.ackNum = 0
                // sender.send_lbw = 1
                userSend[sender]
                sender.curState = Established
                sender.seqNum' = 3
                sender.ackNum' = 0
                // sender.send_lbw' = 2
                one p: Packet | {
                    p.dst = sender.connectedNode
                    p.src = sender
                    sender.sendBuffer' = sender.sendBuffer + p
                    p.pSeqNum = 3
                    p.pAckNum != 0
                }
            }
        } is unsat
    }                  

}

test suite for Send {

    // SAT TESTS
    // the size of the packets on the network should increase
    test expect {
        validNetworkIncrease: {
            some sender: Node | {
                Send[sender]
            }
            #{Network.packets'} > #{Network.packets}
        } is sat
    }

    // the packets from the node that sends should be in the network at the next step
    test expect {
        correctPacketsInNetwork: {
            some sender: Node | {
                Send[sender]
                all packet: sender.sendBuffer | {
                    packet in Network.packets'
                    not packet in Network.packets
                }
            }
            #{Network.packets'} > #{Network.packets}
        } is sat
    }

    // the send buffer becomes empty of the sender
    test expect {
        emptySendBuffer: {
            all sender: Node | {
                Send[sender] implies #{sender.sendBuffer'} = 0
            }
        } is sat
    }

    // UNSAT TESTS

    // the send buffer does not empty
    test expect {
        nonemptySendBuffer: {
            some sender: Node | {
                Send[sender]
                #{sender.sendBuffer'} != 0
            }
        } is unsat
    }
    test expect {
        nonemptySendBuffer2: {
            some sender: Node | {
                Send[sender]
                some packet: Packet | {
                    packet in sender.sendBuffer'
                }
            }
        } is unsat
    }

    // not all the right packets go in the network
    test expect {
        incorrectPacketsInNetwork: {
            some sender: Node | {
                Send[sender]
                some packet: sender.sendBuffer | {
                    not packet in Network.packets'
                }
            }
        } is unsat
    }
    // size of packets in network decreases
    test expect {
        incorrectPacketsInNetwork2: {
            some sender: Node | {
                #{sender.sendBuffer} > 0
                Send[sender]
            }
            #{Network.packets'} < #{Network.packets}
        } is unsat
    }
}

pred emptyNet {
    #{Network.packets'} = 0
}

pred destination {
        some packet: Network.packets | {
        let dest = packet.dst | {
            dest.receiveBuffer' = dest.receiveBuffer + packet
        }
        }
}

test suite for Transfer {

    nonChangingPackets: assert all p: Packet | packetDoesNotChange[p] is necessary for Transfer
    somethingInNetwork: assert #{Network.packets} > 0 is necessary for Transfer
    destIncreases: assert Transfer is sufficient for destination
    // becomesEmpty: assert Transfer is sufficient for emptyNet

    // SAT Condition

    // size of the destination's receiveBuffer increases by one
    test expect {
        receiveBufferCorrectIncrease: {
            Transfer
            #{Network.packets} > 0 => {
                some packet: Network.packets | {
                    let dest = packet.dst | { 
                        #{dest.receiveBuffer'} >  #{dest.receiveBuffer}
                    } 
                }
            }
        } is sat
    } 

    // nothing changes if the size of Networks is 0

    // destination remains the same
    test expect {
        sameDest: {
            Transfer
            some packet: Network.packets | {
                let dest = packet.dst | { 
                    dest.curState' = dest.curState
                    dest.sendBuffer' = dest.sendBuffer
                    dest.seqNum' = dest.seqNum
                    dest.ackNum' = dest.ackNum
                    dest.connectedNode' = dest.connectedNode
                    dest.send_next' = dest.send_next
                    dest.recv_next' = dest.recv_next
                } 
            }            
        } is sat
    }

    // all other nodes remain the same
    test expect {
        allNodesSame: {
            some packet: Network.packets | {
                let dest = packet.dst | { 
                    Transfer implies (all n: Node - dest | nodeDoesNotChange[n])
                } 
            }     
        } is sat
    } 

    // the packets do not change
    test expect {
        samePackets: {
            Transfer
            all p: Packet | packetDoesNotChange[p]
        } is sat
    } 

    // UNSAT Conditions

    // some node changes
    test expect {
        changingNode: {
            Transfer
            some n: Node | n.curState' != n.curState
        } is unsat
    } 

    // the packet changes
    test expect {
        changingPacket: {
            Transfer
            some p: Packet | p.src' != p.src
        } is unsat
    } 

    // Size of the network increases
    test expect {
        sameSizeNet: {
            Transfer
            #{Network.packets'} > #{Network.packets}
        } is unsat
    } 

    // size of the network stays the same
    test expect {
        sameSizeNet2: {
            Transfer
            #{Network.packets'} = #{Network.packets}
        } is unsat
    } 
}



test suite for Receive {   
    // SAT Condition

    // network does not change
    test expect {
        sameSNet: {
            some n: Node | {
                Receive[n]
            }
            #{Network.packets'} = #{Network.packets}
        } is sat
    } 

    // Receive buffer empties
    test expect {
        emptyingReceive: {
            some node : Node | {
                #{node.receiveBuffer'} = subtract[#{node.receiveBuffer},1]
                Receive[node]
            }
        } is sat
    } 

    test expect {
        emptyingReceive2: {
            some node : Node | {
                Receive[node] => 
                #{node.receiveBuffer'} = 0
            }
        } is sat
    } 

    // closed means SynSent
    test expect {
        becomesSynReceived: {
            some node : Node | {
                (Receive[node] and node.curState = Closed) => 
                    node.curState' = SynReceived
            }
        } is sat
    } 

    // send next changes
    test expect {
        newNext: {
            some node : Node | {
                (Receive[node] and node.curState = Closed) => 
                    node.send_next' != node.send_next
            }
        } is sat
    } 

    // at SynReceived means established
    test expect {
        establishedNext: {
            some node : Node | {
                (Receive[node] and node.curState = SynReceived) => 
                    node.curState' = Established
            }
        } is sat
    } 

    // normal communications
    test expect {
        normalCommunication: {
            some node : Node | {
                some packet: node.receiveBuffer | {
                    let srcNode = packet.src | {
                        (Receive[node] and node.curState = Established and packet in DataPacket) => 
                            node.recv_next' = add[packet.pSeqNum, 1]
                    }
                }
            }
        } is sat
    } 

    test expect {
        normalCommunication2: {
            some node : Node | {
                some packet: node.receiveBuffer | {
                    let srcNode = packet.src | {
                        (Receive[node] and node.curState = Established and packet in AckPacket) => 
                            nodeDoesNotChange[node]
                    }
                }
            }
        } is sat
    } 

    test expect {
        sameSNet2: {
            some node : Node | {
                some packet: node.receiveBuffer | {
                    let srcNode = packet.src | {
                        node.receiveBuffer' = node.receiveBuffer - packet

                    }
                }

                Receive[node]
            }
        } is sat
    } 
    test expect {
        sameSNet3: {
            some n: Node | {
                Receive[n]
            }
            #{Network.packets'} = #{Network.packets}
        } is sat
    } 
}

test suite for Close {
    test expect {
        mustBeEstablishedOrEnd: { 
            some disj sender, receiver: Node  {
               Close[sender, receiver]
                sender.curState = Established
                receiver.curState = SynReceived
            }
        } for exactly 2 Node, exactly 4 Packet is unsat
        achievableBidirectional: {
            some disj sender, receiver: Node  {
               eventually Close[sender, receiver]
               eventually Close[receiver, sender]
            }
        } for exactly 2 Node, exactly 4 Packet is sat
        noBuffers: {
            some disj sender, receiver: Node  {
               Close[sender, receiver]
               #{sender.sendBuffer} > 0
            }
        } for exactly 2 Node, exactly 4 Packet is unsat
    } 
}


// /* SYSTEM TESTS */
pred receives {
    some disj sender, receiver: Node | {
        eventually {Receive[sender]}
    }
}

pred closes {
    some disj sender, receiver: Node  {
        eventually sender.curState = Closed
        eventually receiver.curState = Closed
    }
}


// /* TRACES TESTS */
test suite for traces {
    // Any transfer triggers a receive
    transferMeansReceive: assert (traces and Transfer) implies receives is sat for exactly 2 Node, exactly 4 Packet
    // Must finish
    test expect {
        mustFinish: {
             traces
            and
            (not eventually closes)
        } for exactly 2 Node, exactly 4 Packet is unsat
        alwaysValid: {
            traces
            and
            (not always validState)
        } for exactly 2 Node, exactly 4 Packet is unsat
        // A sending means that an open happened.
        sendMeansOpen: { 
            some disj sender, receiver: Node  {
                eventually {userSend[sender]}
                traces
                not once {Open[sender, receiver]}
            }
        } for exactly 2 Node, exactly 4 Packet is unsat
        basic: {
            traces
        } for exactly 2 Node, exactly 4 Packet is sat
        // At one point init
        atOnePointInit: {
            traces
            and
            (not once init)
        } for exactly 2 Node, exactly 4 Packet is unsat
    } 
}
