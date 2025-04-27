"""
Model of the Tahoe congestion control algorithm.
Completed in Python Z3. The goals of this model are:

1. To provide a formal model of the Tahoe congestion control algorithm.
2. To define the properties of the Tahoe congestion control algorithm.
3. To verify correctness of the Tahoe congestion control algorithm.
4. To outline the constraints of the Tahoe congestion control algorithm.
5. To visualize the Tahoe congestion control algorithm, and how it works.
"""

from z3 import *
import matplotlib.pyplot as plt

from enum import IntEnum

class AckType(IntEnum):
    NORMAL_ACK = 0
    TIMEOUT_ACK = 1
    DUPLICATE_ACK = 2


class Tahoe(object):
    def __init__(self, T, acks):
        """Constructor of the Tahoe class"""
        # Solver
        self.s = Solver()

        # Initial conditions
        self.cwnd = [Int(f'cwnd_{t}') for t in range(T)]
        self.ssthresh = [Int(f'ssthresh_{t}') for t in range(T)]
        self.rtt = [Int(f'rtt_{t}') for t in range(T)]
        self.acks = [Int(f'ack_{t}') for t in range(T)]

        for t in range(len(self.acks)):
            self.s.add(self.acks[t] == int(acks[t]))  # Connect input list to model
    
    def solve_congestion(self):
        # We define an initial state
        self.s.add(self.cwnd[0] == 1)
        self.s.add(self.ssthresh[0] == 64)
        self.s.add(self.rtt[0] == 0)

       
        # We loop through time and define the constraints of the Tahoe congestion control algorithm.
        for t in range(1, len(self.rtt)):
            # RTT should scale linearly
            self.s.add(self.rtt[t] == self.rtt[t-1] + 1)
            # Congestion window and ssthresh must always be greater than 0
            self.s.add(self.cwnd[t] > 0)
            self.s.add(self.ssthresh[t] > 0)

            # Based on ACKs, we have different constraints to follow:
            cur_ack = self.acks[t - 1]
            # First we handle the normal ACK
            self.s.add(
                If(cur_ack == int(AckType.NORMAL_ACK),
                   If(self.cwnd[t - 1] < self.ssthresh[t - 1],
                      And(self.cwnd[t] == self.cwnd[t-1] * 2, 
                          self.ssthresh[t] == self.ssthresh[t-1]),
                      And(self.cwnd[t] == self.cwnd[t-1] + 1,
                          self.ssthresh[t] == self.ssthresh[t-1])),
                    True)
            )

            # Then we handle the timeout ACK
            self.s.add(
                If(Or(cur_ack == int(AckType.TIMEOUT_ACK), cur_ack == int(AckType.DUPLICATE_ACK)),
                    And(
                        self.ssthresh[t] == self.cwnd[t-1] / 2,
                        self.cwnd[t] == 1
                    ),
                    True)
                )
        
        
        # We see if with the given input, we can maintain a correct Tahoe
        if self.s.check() == sat:
            return self.s.model()
        else:
            raise Exception("No valid congestion control solution found!")

    def verify_congestion(self, answer):
       pass

def produce_graph(tahoe_model, ans):
    # """Produce a graph of the congestion control algorithm"""
    # plt.xlabel('RTT (Round Trip Time)')
    # plt.ylabel('Congestion Window Size')
    # plt.title('Tahoe Congestion Control Algorithm')

    # # We make use of the model and answer to plot the graph.

    # cwnd_vals = [ans.evaluate(tahoe_model.cwnd[t]).as_long() for t in range(len(tahoe_model.cwnd))]
    # rtt_vals = [ans.evaluate(tahoe_model.rtt[t]).as_long() for t in range(len(tahoe_model.rtt))]

    # plt.plot(rtt_vals, cwnd_vals, marker='o')

    # plt.show()
    """Produce a graph of the congestion control algorithm with values of cwnd, ack, and ssthresh"""
    plt.xlabel('RTT (Round Trip Time)')
    plt.ylabel('Congestion Window Size')
    plt.title('Tahoe Congestion Control Algorithm')

    # We make use of the model and answer to plot the graph.
    cwnd_vals = [ans.evaluate(tahoe_model.cwnd[t]).as_long() for t in range(len(tahoe_model.cwnd))]
    rtt_vals = [ans.evaluate(tahoe_model.rtt[t]).as_long() for t in range(len(tahoe_model.rtt))]
    ssthresh_vals = [ans.evaluate(tahoe_model.ssthresh[t]).as_long() for t in range(len(tahoe_model.ssthresh))]
    ack_vals = [ans.evaluate(tahoe_model.acks[t]).as_long() for t in range(len(tahoe_model.acks))]

    # Plot congestion window values.
    plt.plot(rtt_vals, cwnd_vals, marker='o', label='cwnd')

    # Annotate each point with its cwnd, ack, and ssthresh values.
    for t in range(len(rtt_vals)):
        plt.annotate(
            f'{cwnd_vals[t]} (ack: {ack_vals[t]}, ssthresh: {ssthresh_vals[t]})',
            (rtt_vals[t], cwnd_vals[t]),
            textcoords="offset points",
            xytext=(0, 5),
            ha='center',
            fontsize=8
        )

    plt.show()

if __name__ == "__main__":
    acks = [
        AckType.NORMAL_ACK,
        AckType.NORMAL_ACK,
        AckType.NORMAL_ACK,
        AckType.NORMAL_ACK,
        AckType.NORMAL_ACK,
        AckType.NORMAL_ACK,
        AckType.NORMAL_ACK,
        AckType.TIMEOUT_ACK,
        AckType.NORMAL_ACK,
        AckType.NORMAL_ACK,
        AckType.NORMAL_ACK,
        AckType.NORMAL_ACK,
        AckType.NORMAL_ACK,
        AckType.TIMEOUT_ACK,
        AckType.NORMAL_ACK,
    ]

    tahoe = Tahoe(15, acks)
    
    # We create a congestion solution for the acks received.
    ans = tahoe.solve_congestion()
    produce_graph(tahoe, ans)

    # We verify that the congestion solution passes all our constraints.
    # for a proper Tahoe congestion control algorithm.
    print(tahoe.verify_congestion(ans))