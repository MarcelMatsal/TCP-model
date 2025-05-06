# TCP Temporal Forge Model
## Demo Video

[DEMO OF OUR MODEL](https://drive.google.com/file/d/1NcSaZ0yb0s9M2YIKugwx9Dj-v9i2RaOg/view?usp=sharing)
## Project Overview

Our project models the flow of a TCP connection between two nodes. This includes the 3-way handshake to open the connection, basic sending and receiving of acks, and standard active + passive closing of the connection.

Our model mostly abstracts away the user application and actual data within packets, and has the TCP stack immediately push packets it receives up to the user, without concerning itself with the size of the buffer or needing the user to call recv. But the packets do have accurate sequence and ack numbers (1 byte data packets). 

<img width="450" alt="ClosedConnection" src="https://github.com/user-attachments/assets/be94862d-0d01-4e28-ac62-a53ec1c34a44" />
<img width="450" alt="EstablishedSendingData" src="https://github.com/user-attachments/assets/7bfb19ea-02f3-4d83-8788-b3cacf846973" />
<img width="450" alt="Closing Sequence" src="https://github.com/user-attachments/assets/edee48e7-b261-4343-b8de-657aaff82f19" />


## Takeaways from our model:

In our initial project proposal, we said that our stakeholders mostly involved people who want to learn about TCP. Thus, our model presented the following in teaching about the constraints of TCP by defining the formal aspects of the algorithm:
In working on our model, we had an initial valid_state predicate that we often had to redefine as we went along with our modeling process. This helped us understand that while TCP is sequential and well defined, it has constantly shifting constraints that need to be met: it is a highly dynamic system that doesn’t conform to a “one size fits all” valid state checker, and is prone to overconstraint.
In the difficulties of causing a sequential trace to occur, we learned greatly what guardrails have to be put in place for each “step of TCP”: what do the packets have to look like? The buffers for each node? The state of each node? While some of this was of course abstracted due to the nature and limitations of Temporal Forge and our model, we feel as though the model clearly articulates, through analysis of its predicates, what constraints bound some step in the algorithm to take place.
This is probably the clearest takeaway from our model: in an effort to produce a sequential model, we had to define carefully what the guards were for each “next step” of TCP, and formalized how someone writing a TCP algorithm might change parameters and introduce checks throughout their algorithm.
In addition to these takeaways, the model provides a “step-by-step” approach to understanding TCP for a student, or educator trying to explain the algorithm. The unique step-by-step nature of the model is useful in letting a learner understand how parameters of the system change at each time step, and toggle back and forth between different steps.

Moreover, our visualization acts as a tool, not just for the algorithm, but for explaining and understanding the sequential nature of the algorithm. Our model shows nodes in a network, and how packets interact and move between nodes through establishing, sending and receiving data, and closing a TCP connection. We all left the project with a far greater understanding of how TCP functions.

We also took away quite a bit from the modeling of the Tahoe Congestion Control algorithm via the verification of congestion:
Round Trip Time always scaling linearly, congestion windows and slow start threshold always being greater than 0:
Which led to an interesting rabbit hole as to what happens when congestion control is 1, and sshtresh has to become half of congestion control. It cannot become 0, so we made the design choice to just set it to 1. Research was inconclusive as to what should actually happen here, and prompts us to further ask and understand this edge case.
What it means for a congestion window to be equal to 1: verifying that means the previous ack has to be a timeout or duplicate.
The constraints on the congestion window and slow start threshold in response to different acks: when congestion windows scale linearly vs exponentially, and how and when the slow start threshold changes.

The congestion control model formally defined how each of these values interact with one another, and what must be maintained through a response to congestion issues. In effect, it can greatly help a student or researcher understand and analyze responses to congestion, in knowing how these parameters shift with different inputs. The provided visualization is also greatly helpful in teaching and modeling a congestion response.


## Main predicates:

### Open:
Similar to the connect systcall and will send the SYN packet to start the 3 way handshake, bringing the node to SYN_SENT state.

### userSend:
Used to simulate a user calling the send syscall by adding data to the TCP stack’s send buffer.

### Send:
Mimics the internal TCP stack sending any data in the send buffer across the network. Abstracts away keeping track of the connected node’s receive window.

### Transfer:
Acts as an intermediary router of some sort, taking any packets in the network and forwarding them to the correct destination.

### Receive:
Pred used to handle a node’s TCP stack receiving any type of packet depending on the state of the node, whether that be dealing with a SYN packet by opening up the connection on the listener and responding with a SYN_ACK, handling a data packet by responding with an ACK, etc.

### Close:
Acts as an active close when a user would call the close syscall. Sends a FIN packet and updates the node’s state accordingly.

### init:
Defines the starting/ending state of the temporal trace: the nodes are both closed and connected to each other as well as there being no packets floating around the TCP stacks or network

### traces:
Defines the overall function and flow for TCP as a whole. It is easy to have the predicates and just call them all, but the traces predicate is what allows the system based on its constraints and properties to create the proper traces with the other predicates working together.

We also have some predicates that mirror these mentioned but for retransmission (retransmissionInit, userSendRT, receiveRT, and rtMoves). They are similar to their counterparts for the regular TCP but a little looser to allow for retransmission to occur. Additionally, for its trace we force retransmission to actually occur so that we can see something meaningful about it.

## Additional Topics:
### Trade Offs
While we would’ve liked to produce a system that did more back and forth communication, traces took excessively long amounts of time to produce. Thus, we opted to get at the “bare necessities” of the TCP constraints, and work in a system that seemed to do all requirements at least once.
### Assumptions Made
One assumption/abstraction we made was with buffer sizes, as we made the assumption that buffers could hold any packets coming its way. In addition, within our standard model, we assumed that packets would be sent in order, and not lost. We explored these differences in our retransmission trace. While not necessarily an assumption we made, our traces seemed to prefer to initiate closings from both nodes somewhat one after the other, probably to create smaller traces. We also made the assumption that the network would not be overwhelmed, and that congestion control wasn’t needed. This was mostly due in part to the additional implementation of the Tahoe Congestion Control system, where we could explore that in isolation.
### Limits of Model
One of the difficulties with our model is that it is slow to run, even when using an optimized solver like Glucose, thus, our model mostly shows basic examples (one packet sent with an ack, etc) as opposed to multiple rounds of the system working (and, multiple packets handled concurrently). Due to excessively long trace lengths, we also had to split up retransmission and the rest of the TCP system with establishing and closing connections. The sequential nature of Temporal Forge also made it somewhat difficult to parallelize and model things like retransmission, or maintaining order of when packets were accepted.
### Changing Goals:
Our goals mostly stayed the same throughout the project. We were aiming to produce a basic TCP model, explore retransmission, create a custom visualizer, and also model a Congestion Control algorithm in Z3. Our goal of retransmission (a  target hopeful goal) was changed slightly in that we couldn’t fully integrate it into a system with establishing / closing connections due to excessively long trace lengths (50+ steps). Thus, we feel as though we achieved mostly what we set out to do within the limits of our environment. That being said, the scope of the project was definitely a large effort, especially trying to “force” all aspects of TCP to happen, in a semi defined sequence, and took a bigger time commitment than we expected to “fit things together”. We also feel that in addition to engineering goals, we also met and exceeded our learning goals: we came out of the project with a significantly better understanding of how TCP works, and how to work within Temporal Forge too!
### Understanding an Instance
Understanding an instance of our model will take multiple things into account so we recommend running our custom visualization to facilitate that understanding. To begin, the instance has three main components, the two nodes which are communicating with each other and the network. Each node has a send buffer and receive buffer which are used in conjunction with the network to communicate with the other node. When first looking at the instance, you should look at the current state of the nodes. This represents the different states that nodes can take in an actual TCP connection and helps you to understand what is occuring at the moment. The different states that the node can have are: Closed, SynReceived, SynSent, Established, FinWait1, FinWait2, TimeWait, CloseWait, LastAck. With SynReceived and SynSent having to do with the opening of the connection and FinWait1, FinWait2, TimeWait, CloseWait, and LastAck having to do with closing the connection. When running a trace, you will see how the nodes transition through the different states in the same way that a TCP connection does. This is done through the sending and receiving of different packets through the network (which you will be able to see in the custom visualization). There are four different kinds of packets that can be sent: DataPacket, AckPacket, FinPacket, and Retransmit. Meaning that for basic communication, when receiving a data packet, the node should respond with an AckPacket that is one greater than the sequence number of data packets that it received. These things come together to make the TCP connection and communication and will be able to be seen through a basic trace of running TCP. We also have a trace for Retransmission (which was one of our additional goals), where you should be able to see one node send a sequence number that is greater than what is expected, resulting in the other node sending a retransmit packet telling the node to send the correct information again. It then goes on to send the correct data packet resulting in the node acknowledging that it received the correct thing.

## Testing

We went ahead and tested our predicates to ensure that they were functioning properly. We utilized many different types of tests such as sat/unsat and assertions to make sure that everything was as intended. Additionally, we included some system-wide tests to make sure that properties of the system held and that we could learn about how TCP, and retransmission works. We tested our traces and feel confident about our model.

## Capstone Effort: Congestion Control

In addition to our TCP model that displayed basic communication functionality in Temporal Forge, and a basic retransmission example, Tahoe, a Congestion Control algorithm, was also modeled (in the Python Z3-Solver).

The Tahoe model explores the constraints of how congestion window sizes grow and change through an effort to control data flow in a heavily congested system. The model takes an input of ACKs, and then “solves” to find the ideal response from the Tahoe algorithm. In addition to this solving feature, the Z3 model also has a verification function, which works to confirm that the handling of the congestion window and other parameters always follow the proper constraints of the algorithm.

Finally, the model produces a graph visualizing the congestion window in comparison to Round Trip Time, showing periods of slow starting and additive increase / multiplicative decrease periods.


The Hypothesis library was used to confirm that on any input of ack sequences, the model can solve for a congestion control response, and be verified to hold all expected properties of that response. Moreover, edge case testing was performed to confirm the strength of these testing measures.

### Collaborators: none.

