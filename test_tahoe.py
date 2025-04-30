from hypothesis import given, settings, strategies as st
from typing import Sequence
from tahoe import *

MAX_EXAMPLES = 1_000
settings.register_profile("student", settings(max_examples=MAX_EXAMPLES, deadline=None))
settings.load_profile("student")

@given(st.lists(st.sampled_from(list(AckType)), min_size=1, max_size=40))
def test_verification(ack_sequence):
    """
    Hypothesis test to validate randomly generated lists of packets.
    """
    try:
        is_valid_congestion_response(ack_sequence)
    except Exception as e:
        assert False, f"Hypothesis test failed unexpectedly: {e}"
    assert True

def is_valid_congestion_response(ack_sequence: Sequence[AckType]) -> bool:
    """
    This function checks if a given sequence of ACKs is valid for the Tahoe congestion control algorithm.
    """
    # Initialize variables
    tahoe = Tahoe(len(ack_sequence), ack_sequence)
    ans = tahoe.solve_congestion()

    try:
        tahoe.verify_congestion(ans)
    except Exception:
        return False
    return True


if __name__ == '__main__':
    #### Include hand-written tests for is_valid_...() in this section

    # Simple basecase, one timeout
    assert is_valid_congestion_response(
        [
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
            AckType.NORMAL_ACK,
            AckType.NORMAL_ACK,
            AckType.NORMAL_ACK,
            AckType.NORMAL_ACK,
            AckType.NORMAL_ACK,
            AckType.NORMAL_ACK,
            AckType.NORMAL_ACK,
        ]
    )

    # No timeouts
    assert is_valid_congestion_response(
        [
            AckType.NORMAL_ACK,
            AckType.NORMAL_ACK,
            AckType.NORMAL_ACK,
            AckType.NORMAL_ACK,
            AckType.NORMAL_ACK,
        ]
    )

    # Multiple timeouts
    assert is_valid_congestion_response(
        [
            AckType.NORMAL_ACK,
            AckType.NORMAL_ACK,
            AckType.TIMEOUT_ACK,
            AckType.NORMAL_ACK,
            AckType.NORMAL_ACK,
            AckType.TIMEOUT_ACK,
            AckType.NORMAL_ACK,
        ]
    )

    # Timeouts in a row
    assert is_valid_congestion_response(
        [
            AckType.NORMAL_ACK,
            AckType.NORMAL_ACK,
            AckType.TIMEOUT_ACK,
            AckType.TIMEOUT_ACK,
            AckType.NORMAL_ACK,
            AckType.NORMAL_ACK,
        ]
    )

    # Timeout at the beginning
    assert is_valid_congestion_response(
        [
            AckType.TIMEOUT_ACK,
            AckType.NORMAL_ACK
        ]
    )

    # Just one timeout
    assert is_valid_congestion_response(
        [
            AckType.TIMEOUT_ACK
        ]
    )

    # Just one ack
    assert is_valid_congestion_response(
        [
            AckType.NORMAL_ACK
        ]
    )

    # Timeout at end
    assert is_valid_congestion_response(
        [
            AckType.NORMAL_ACK,
            AckType.NORMAL_ACK,
            AckType.TIMEOUT_ACK
        ]
    )

    # Using hypothesis to test.
    test_verification()
    print("All tests pass!!")