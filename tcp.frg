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
    ackNum: one Int,
}

one sig Sender extends Node {
    var sendBuffer = set Packet
    var seqNum: one Int,
    var ackNum: one Int,
    var receiver: lone Receiver,
}

one sig Receiver extends Node {
    var seqNum: one Int,
    var ackNum: one Int,
    var sender: lone Sender,
}

one sig Network {
    var packets: set Packet,
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

run {
    traces for ...
}





















