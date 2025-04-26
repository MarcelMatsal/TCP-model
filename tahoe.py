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
    
    def solve_congestion(self):
        pass

    def verify_congestion(self, answer):
       pass

def produce_graph(tahoe_model, ans):
    """Produce a graph of the congestion control algorithm"""
    plt.xlabel('RTT (Round Trip Time)')
    plt.ylabel('Congestion Window Size')
    plt.title('Tahoe Congestion Control Algorithm')

    # We make use of the model and answer to plot the graph.



    plt.show()

if __name__ == "__main__":
    acks = [
        AckType.NORMAL,
        AckType.NORMAL,
        AckType.TIMEOUT,
        AckType.NORMAL,
        AckType.DUPLICATE,
        AckType.NORMAL,
        AckType.NORMAL,
        AckType.TIMEOUT,
        AckType.NORMAL,
        AckType.NORMAL,
        AckType.NORMAL,
        AckType.NORMAL,
        AckType.NORMAL,
        AckType.DUPLICATE,
        AckType.NORMAL,
    ]

    tahoe = Tahoe(15, acks)
    
    # We create a congestion solution for the acks received.
    ans = tahoe.solve_congestion()
    produce_graph(ans)

    # We verify that the congestion solution passes all our constraints.
    # for a proper Tahoe congestion control algorithm.
    print(Tahoe.verify_congestion(ans))