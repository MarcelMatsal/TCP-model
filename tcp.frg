#lang forge/temporal

---------- Definitions ----------

abstract sig State {
    
}

sig Closed extends State {
}
sig SynReceived extends State {
}
sig SynSent extends State {
}
sig Established extends State {
}
sig FinWait1 extends State {
}
sig FinWait2 extends State {
}
sig TimeWait extends State {
}
sig CloseWait extends State {
}

abstract sig Node {
    var curState: one State,
    var receiveBuffer: set Packet
}

sig Packet {
    src: one Node,
    dst: one Node,
    seqNum: one Int,
    ackNum: one Int
}

one sig Sender extends Node {
    var sendBuffer: set Packet,
    var seqNum: one Int,
    var ackNum: one Int,
    var receiver: lone Receiver
}

one sig Receiver extends Node {
    var seqNum: one Int,
    var ackNum: one Int,
    var sender: lone Sender
}

one sig Network {
    var packets: set Packet
}

pred validState {
// all seq number >= 0
}

pred init {
    Sender.curState = Closed
    Receiver.curState = Closed
    no Sender.sendBuffer
    no Receiver.receiveBuffer
    no Network.packets
    no Sender.receiver
    no Receiver.sender
}

pred Connected[node1, node2: Node] {
}

pred Open [node: Node] {
    Sender.curState = Closed
    Sender.receiver = none
    #{Sender.sendBuffer} = 0 // empty

    Sender.receiver' = node
    Sender.curState' = SynSent
    some i: Int | {
        i >= 0
        Sender.seqNum' = i
    }
    some packet: Packet | {
        packet.src = Sender
        packet.dst = Sender.receiver'
        packet.seqNum = Sender.seqNum'
        packet.ackNum = Sender.ackNum

        Sender.sendBuffer' = Sender.sendBuffer + packet
    }
}

pred userSend {

}

pred Send {
    #{Sender.sendBuffer} > 0 => {
        Network.packets' = Network.packets + Sender.sendBuffer
        #{Sender.sendBuffer'} = 0
    }
}

pred Transfer {
    all packet: Packet | {
        packet in Network.packets => {
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
        

        // syn received -> go into established state

        // syn sent -> send back last part of handshake
        // go into established state

        // established
        //  make sure packet has ack flag
        //  if ack is > send_una and <= send_next
        //    update send_una (the last byte that has been acked)
        //  if seq <= rcv_next
        //    receive data
        //    increment rcv_next (next byte to be received)
        // send back ack (send_next, rcv_next)
    }
}

pred Close {

}

pred traces {
    init
}

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

run BasicTrac: {
    // things that constrain the runs and ensure validity
    init
    validState
    // things that constrain the actions that happen
    always {
        all disj n1, n2: Node | {

            // one of them must be the sender and the other the receiver
            senderAndReceiver[n1,n2]

            // possible actions to take
            // three step handshake, send info or close connection
            threeStepHandshake[n1, n2] or sendInfo[n1, n2] or closeConnection[n1, n2] or doNothing

            // if a connection is ever opened then it must close eventually
            // (connectionOpened could be like a flag)
            (connectionOpened[n1] and connectionOpened[n2]) implies eventually {closeConnection[n1, n2]}
        }
    }
} for 2 Node




run {
    // traces for ...
}





















