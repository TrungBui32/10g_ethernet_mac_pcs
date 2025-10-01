import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

# Reference 64-bit parallel 10GBASE-R scrambler
# Polynomial: 1 + x^39 + x^58
# Mapping for LSB-first 64-bit words:
#   out[i] = in[i] ^ state[6 + i] ^ state[25 + i]
#   state  <= {out[0..63], state[64..127]}

DATA_WIDTH = 64

def word_to_bits_lsb_first(word, width=64):
    return [(word >> i) & 1 for i in range(width)]

def bits_to_word_lsb_first(bits):
    w = 0
    for i, b in enumerate(bits):
        if b & 1:
            w |= (1 << i)
    return w

class Scrambler64Ref:
    def __init__(self, seed_ones=True):
        # 128-bit state: index 0 is state[0] (LSB of the Verilog vector)
        self.state = [1]*128 if seed_ones else [0]*128

    def step(self, in_word: int) -> int:
        in_bits = word_to_bits_lsb_first(in_word, DATA_WIDTH)

        out_bits = []
        for i in range(DATA_WIDTH):
            tap58 = self.state[6 + i]   # corresponds to 58 back in this parallel mapping
            tap39 = self.state[25 + i]  # corresponds to 39 back
            out_bits.append(in_bits[i] ^ tap58 ^ tap39)

        out_word = bits_to_word_lsb_first(out_bits)

        # Update state: {out, state[64..127]}
        new_state = [0]*128
        # Lower 64 get old upper 64
        for i in range(64):
            new_state[i] = self.state[64 + i]
        # Upper 64 get new scrambled bits (LSB-first)
        for i in range(64):
            new_state[64 + i] = out_bits[i]

        self.state = new_state
        return out_word


class ScramblerTestbench:
    def __init__(self, dut):
        self.dut = dut
        self.scr_hist = []

    async def reset(self):
        # Active-high reset
        self.dut.rst.value = 1
        self.dut.data_in.value = 0
        await ClockCycles(self.dut.clk, 4)
        self.dut.rst.value = 0
        await ClockCycles(self.dut.clk, 2)

    async def monitor_out_continuous(self, num_cycles):
        self.scr_hist = []
        for cycle in range(num_cycles):
            await RisingEdge(self.dut.clk)
            try:
                v = int(self.dut.data_out.value)
                self.scr_hist.append(v)
                self.dut._log.info(f"Cycle {cycle}: out=0x{v:016x}")
            except ValueError:
                self.scr_hist.append(None)
                self.dut._log.info(f"Cycle {cycle}: out={self.dut.data_out.value} (unresolved)")

    async def send_data(self, words):
        # Drive one 64b word per cycle
        for w in words:
            await RisingEdge(self.dut.clk)
            self.dut.data_in.value = w
            self.dut._log.info(f"  Sending: 0x{w:016x}")
        # Deassert input after final word
        await RisingEdge(self.dut.clk)
        self.dut.data_in.value = 0
        await ClockCycles(self.dut.clk, 5)

    async def send_data_with_monitoring(self, words):
        self.scr_hist = []
        for i, w in enumerate(words):
            await RisingEdge(self.dut.clk)
            # Log current output before driving new input (same style as your CRC test)
            try:
                v = int(self.dut.data_out.value)
                self.scr_hist.append(v)
                self.dut._log.info(f"Cycle {i}: out=0x{v:016x}")
            except ValueError:
                self.scr_hist.append(None)
                self.dut._log.info(f"Cycle {i}: out={self.dut.data_out.value} (unresolved)")

            self.dut.data_in.value = w
            self.dut._log.info(f"  Sending: 0x{w:016x}")

        # Observe a few more cycles after inputs stop
        for j in range(10):
            await RisingEdge(self.dut.clk)
            if j == 0:
                self.dut.data_in.value = 0
            try:
                v = int(self.dut.data_out.value)
                self.scr_hist.append(v)
                self.dut._log.info(f"Post-data cycle {j}: out=0x{v:016x}")
            except ValueError:
                self.scr_hist.append(None)
                self.dut._log.info(f"Post-data cycle {j}: out={self.dut.data_out.value} (unresolved)")

    def compute_expected(self, words):
        """
        Use the Python reference model to compute expected scrambled words.
        Assumes the DUT seeds its state to all ones on reset (rst=1), then rst=0 for operation.
        """
        ref = Scrambler64Ref(seed_ones=True)
        expected = []
        for w in words:
            expected.append(ref.step(w))
        return expected


@cocotb.test()
async def test_scrambler_with_monitoring(dut):
    tb = ScramblerTestbench(dut)

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await tb.reset()

    # Test stimulus (64-bit words)
    test_words = [
        0x78D5_5555_5555_5555,
        0xBBAA_5544_3322_1100,
        0xFFEEDDCC_00000008,   # NB: This is 64-bit; ensure value is within 64 bits.
        0xA1B2_C3D4_1234_5678,
        0xDEAD_BEEF_8765_4321,
        0xFEDC_BA98_55AA_33CC,
    ]

    await tb.send_data_with_monitoring(test_words)

    # Compare final output in the history to the expected last word
    expected_words = tb.compute_expected(test_words)

    dut._log.info("=== SCRAMBLER HISTORY ===")
    for i, v in enumerate(tb.scr_hist):
        if v is not None:
            dut._log.info(f"Cycle {i}: 0x{v:016x}")
        else:
            dut._log.info(f"Cycle {i}: unresolved")

    # The output corresponding to the k-th input appears on the cycle after that input is applied,
    # depending on the DUT’s combinational path. Here we compare the sequence directly.
    # Grab the last DUT output sample taken right after the last input was applied.
    # Adjust indexing if your DUT has extra latency.
    # For a purely combinational data_out with registered state, data_out matches expected in the same cycle.
    got_last = None
    for v in reversed(tb.scr_hist):
        if v is not None:
            got_last = v
            break

    exp_last = expected_words[-1]
    dut._log.info(f"Final expected out: 0x{exp_last:016x}")
    dut._log.info(f"Final DUT out:      0x{got_last:016x}")

    assert got_last == exp_last, (
        f"Scrambler mismatch on final word: got 0x{got_last:016x}, expected 0x{exp_last:016x}"
    )


@cocotb.test()
async def test_scrambler_parallel_monitoring(dut):
    tb = ScramblerTestbench(dut)

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await tb.reset()

    test_words = [
        0x1234_5678_9ABC_DEF0,
        0x1122_3344_5566_7788,
        0xCAFEBABE_DEAD_BEEF,
        0x0F0E_0D0C_0B0A_0908,
    ]

    monitor_cycles = len(test_words) + 12
    monitor_task = cocotb.start_soon(tb.monitor_out_continuous(monitor_cycles))

    await ClockCycles(dut.clk, 3)
    send_task = cocotb.start_soon(tb.send_data(test_words))

    await send_task
    await monitor_task

    # Compute expected last output and compare to final observed
    expected_words = tb.compute_expected(test_words)
    final_expected = expected_words[-1]
    final_got = next((v for v in reversed(tb.scr_hist) if v is not None), 0)

    dut._log.info(f"Final expected out: 0x{final_expected:016x}")
    dut._log.info(f"Final DUT out:      0x{final_got:016x}")
    assert final_expected == final_got, "Final scrambled word mismatch"


@cocotb.test()
async def test_simple_scrambler_debug_monitored(dut):
    tb = ScramblerTestbench(dut)

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await tb.reset()

    test_words = [0x1234_5678_9ABC_DEF0]

    await tb.send_data_with_monitoring(test_words)

    ref = Scrambler64Ref(seed_ones=True)
    expected = ref.step(test_words[0])

    last_got = next((v for v in reversed(tb.scr_hist) if v is not None), 0)

    dut._log.info(f"Hardware out: 0x{last_got:016x}")
    dut._log.info(f"Expected out: 0x{expected:016x}")
    dut._log.info(f"Input word:   0x{test_words[0]:016x}")

    assert last_got == expected, "Single-word scramble mismatch"

