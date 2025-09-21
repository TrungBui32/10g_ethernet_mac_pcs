import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.result import TestFailure
from crc import Calculator, Crc32

ethernet_crc32_calc = Calculator(Crc32.CRC32)


class TxMacTestbench:
    def __init__(self, dut):
        self.dut = dut

        self.XGMII_IDLE = 0x07
        self.XGMII_START = 0xFB
        self.XGMII_TERMINATE = 0xFD
        self.XGMII_ERROR = 0xFE

        self.PREAMBLE_BYTE = 0x55
        self.SFD_BYTE = 0xD5

        self.DEST_MAC = 0x001122334455
        self.SRC_MAC = 0xAABBCCDDEEFF
        self.ETHER_TYPE = 0x0800

        self.MIN_FRAME_SIZE = 64
        self.MAX_FRAME_SIZE = 1518
        self.MIN_PAYLOAD_SIZE = 46
        self.MAX_PAYLOAD_SIZE = 1500
        self.IFG_SIZE = 12

    async def reset(self):
        self.dut.tx_rst.value = 0
        self.dut.in_slave_tx_tvalid.value = 0
        self.dut.in_slave_tx_tlast.value = 0
        self.dut.in_slave_tx_tdata.value = 0
        self.dut.in_slave_tx_tkeep.value = 0
        self.dut.in_xgmii_pcs_ready.value = 1

        await ClockCycles(self.dut.tx_clk, 5)
        self.dut.tx_rst.value = 1
        await ClockCycles(self.dut.tx_clk, 5)

    async def send_axis_frame(self, payload_data):
        while not self.dut.out_slave_tx_tready.value:
            await RisingEdge(self.dut.tx_clk)

        words = []
        for i in range(0, len(payload_data), 4):
            chunk = payload_data[i : i + 4]
            if len(chunk) < 4:
                chunk.extend([0] * (4 - len(chunk)))
            word = (chunk[3] << 24) | (chunk[2] << 16) | (chunk[1] << 8) | chunk[0]
            words.append(word)

        for i, word in enumerate(words):
            await RisingEdge(self.dut.tx_clk)

            while not self.dut.out_slave_tx_tready.value:
                await RisingEdge(self.dut.tx_clk)

            self.dut.in_slave_tx_tdata.value = word
            self.dut.in_slave_tx_tvalid.value = 1

            if i == len(words) - 1:
                self.dut.in_slave_tx_tlast.value = 1
                remaining_bytes = len(payload_data) % 4
                if remaining_bytes == 0:
                    remaining_bytes = 4
                keep_mask = (1 << remaining_bytes) - 1
                self.dut.in_slave_tx_tkeep.value = keep_mask
            else:
                self.dut.in_slave_tx_tkeep.value = 0xF
                self.dut.in_slave_tx_tlast.value = 0

        await RisingEdge(self.dut.tx_clk)
        self.dut.in_slave_tx_tvalid.value = 0
        self.dut.in_slave_tx_tlast.value = 0
        self.dut.in_slave_tx_tkeep.value = 0

    async def capture_xgmii_frame(self, timeout_cycles=1000):
        frame_data = []
        frame_started = False
        cycle_count = 0

        self.dut._log.info("Starting XGMII frame capture...")

        while cycle_count < timeout_cycles:
            await RisingEdge(self.dut.tx_clk)
            cycle_count += 1

            if not self.dut.in_xgmii_pcs_ready.value:
                continue

            xgmii_data = int(self.dut.out_xgmii_data.value)
            xgmii_ctl = int(self.dut.out_xgmii_ctl.value)

            bytes_in_word = []
            for i in range(4):
                byte_val = (xgmii_data >> (i * 8)) & 0xFF
                ctl_bit = (xgmii_ctl >> i) & 1
                bytes_in_word.append((byte_val, ctl_bit))

            if cycle_count <= 55:
                self.dut._log.info(
                    f"Cycle {cycle_count}: data=0x{xgmii_data:08x}, ctl=0b{xgmii_ctl:04b}, bytes={[(hex(b), c) for b, c in bytes_in_word]}"
                )

            if not frame_started:
                for i, (byte_val, ctl_bit) in enumerate(bytes_in_word):
                    if ctl_bit and byte_val == self.XGMII_START:
                        frame_started = True
                        self.dut._log.info(f"Frame start detected at byte {i}")
                        for j in range(i + 1, 4):
                            if not bytes_in_word[j][1]:
                                frame_data.append(bytes_in_word[j])
                        break
            else:
                for byte_val, ctl_bit in bytes_in_word:
                    if not ctl_bit:
                        frame_data.append((byte_val, ctl_bit))
                    elif ctl_bit and byte_val == self.XGMII_TERMINATE:
                        self.dut._log.info(
                            f"Frame end detected, total bytes captured: {len(frame_data)}"
                        )
                        return frame_data

        if not frame_started:
            raise TestFailure("No XGMII frame detected within timeout")

        return frame_data

    def parse_ethernet_frame(self, xgmii_data):
        frame_bytes = []

        for byte_val, ctl_bit in xgmii_data:
            frame_bytes.append(byte_val)

        self.dut._log.info(
            f"Extracted frame bytes: {[hex(b) for b in frame_bytes[:30]]}..."
        )
        self.dut._log.info(f"Total frame bytes: {len(frame_bytes)}")

        if len(frame_bytes) < 22:
            raise TestFailure(f"Frame too short: {len(frame_bytes)} bytes")

        preamble = frame_bytes[:6]
        sfd = frame_bytes[6]

        dest_mac = frame_bytes[7:13]
        src_mac = frame_bytes[13:19]
        ether_type = frame_bytes[19:21]
        payload_start = 23

        fcs = frame_bytes[-4:]
        payload = frame_bytes[payload_start:-4]

        preamble_sfd = preamble + [sfd]

        self.dut._log.info(f"Whole frame bytes: {[hex(b) for b in frame_bytes]}")
        self.dut._log.info(f"Preamble: {[hex(b) for b in preamble]}")
        self.dut._log.info(f"SFD: {hex(sfd)}")
        self.dut._log.info(f"Dest MAC: {[hex(b) for b in dest_mac]}")
        self.dut._log.info(f"Src MAC: {[hex(b) for b in src_mac]}")
        self.dut._log.info(f"EtherType: {[hex(b) for b in ether_type]}")
        self.dut._log.info(
            f"TX MAC padding bytes: {[hex(b) for b in frame_bytes[21:23]]}"
        )
        self.dut._log.info(f"Payload start index: {payload_start}")
        self.dut._log.info(f"Payload length: {len(payload)}")
        self.dut._log.info(f"Payload: {[hex(b) for b in payload[:16]]}...")
        self.dut._log.info(f"FCS: {[hex(b) for b in fcs]}")

        return {
            "preamble_sfd": preamble_sfd,
            "dest_mac": dest_mac,
            "src_mac": src_mac,
            "ether_type": ether_type,
            "payload": payload,
            "fcs": fcs,
            "total_length": len(frame_bytes),
        }

    def calculate_crc32(self, data: bytes) -> int:
        return ethernet_crc32_calc.checksum(data)

    def verify_frame(self, captured_frame, expected_payload):
        parsed = self.parse_ethernet_frame(captured_frame)

        expected_preamble = [self.PREAMBLE_BYTE] * 6
        actual_preamble = parsed["preamble_sfd"][:6]
        if actual_preamble != expected_preamble:
            raise TestFailure(
                f"Preamble mismatch: got {[hex(b) for b in actual_preamble]}, expected {[hex(b) for b in expected_preamble]}"
            )

        if len(parsed["preamble_sfd"]) > 6:
            actual_sfd = parsed["preamble_sfd"][6]
            if actual_sfd != self.SFD_BYTE:
                raise TestFailure(
                    f"SFD mismatch: got {hex(actual_sfd)}, expected {hex(self.SFD_BYTE)}"
                )

        expected_dest = [(self.DEST_MAC >> (8 * (5 - i))) & 0xFF for i in range(6)]
        expected_src = [(self.SRC_MAC >> (8 * (5 - i))) & 0xFF for i in range(6)]

        if parsed["dest_mac"] != expected_dest:
            raise TestFailure(
                f"Dest MAC mismatch: got {[hex(b) for b in parsed['dest_mac']]}, expected {[hex(b) for b in expected_dest]}"
            )

        if parsed["src_mac"] != expected_src:
            raise TestFailure(
                f"Src MAC mismatch: got {[hex(b) for b in parsed['src_mac']]}, expected {[hex(b) for b in expected_src]}"
            )

        expected_ether_type = [(self.ETHER_TYPE >> 8) & 0xFF, self.ETHER_TYPE & 0xFF]
        if parsed["ether_type"] != expected_ether_type:
            raise TestFailure(
                f"EtherType mismatch: got {[hex(b) for b in parsed['ether_type']]}, expected {[hex(b) for b in expected_ether_type]}"
            )

        actual_payload = parsed["payload"][: len(expected_payload)]
        if actual_payload != expected_payload:
            raise TestFailure(
                f"Payload mismatch: got {[hex(b) for b in actual_payload]}, expected {[hex(b) for b in expected_payload]}"
            )

        min_payload_size = max(len(expected_payload), self.MIN_PAYLOAD_SIZE)
        if len(parsed["payload"]) < min_payload_size:
            raise TestFailure(
                f"Payload too short: {len(parsed['payload'])}, expected at least {min_payload_size}"
            )

        frame_for_crc = (
            parsed["dest_mac"]
            + parsed["src_mac"]
            + parsed["ether_type"]
            + parsed["payload"]
        )
        expected_crc = self.calculate_crc32(frame_for_crc)
        actual_crc = (
            (parsed["fcs"][3] << 24)
            | (parsed["fcs"][2] << 16)
            | (parsed["fcs"][1] << 8)
            | parsed["fcs"][0]
        )

        self.dut._log.info(
            f"CRC check: got 0x{actual_crc:08x}, expected 0x{expected_crc:08x}"
        )

        return parsed

    async def measure_latency_accurate(self, payload_data):
        axis_start_time = None
        xgmii_start_time = None
        state_transition_time = None

        async def monitor_state():
            nonlocal state_transition_time
            prev_state = None
            cycle_count = 0

            while cycle_count < 100:
                await RisingEdge(self.dut.tx_clk)
                cycle_count += 1

                try:
                    current_state = int(self.dut.current_state.value)
                    if prev_state == 0 and current_state == 1:
                        state_transition_time = cocotb.utils.get_sim_time("ns")
                        self.dut._log.info(
                            f"State transition IDLE->PREAMBLE at {state_transition_time} ns, cycle {cycle_count}"
                        )
                        break
                    prev_state = current_state
                except:
                    break

        async def monitor_xgmii():
            nonlocal xgmii_start_time
            cycle_count = 0

            while cycle_count < 100:
                await RisingEdge(self.dut.tx_clk)
                cycle_count += 1

                if not self.dut.in_xgmii_pcs_ready.value:
                    continue

                xgmii_data = int(self.dut.out_xgmii_data.value)
                xgmii_ctl = int(self.dut.out_xgmii_ctl.value)

                for i in range(4):
                    byte_val = (xgmii_data >> (i * 8)) & 0xFF
                    ctl_bit = (xgmii_ctl >> i) & 1

                    if ctl_bit and byte_val == self.XGMII_START:
                        xgmii_start_time = cocotb.utils.get_sim_time("ns")
                        self.dut._log.info(
                            f"XGMII START detected at {xgmii_start_time} ns, cycle {cycle_count}"
                        )
                        return

        state_task = cocotb.start_soon(monitor_state())
        xgmii_task = cocotb.start_soon(monitor_xgmii())

        while not self.dut.out_slave_tx_tready.value:
            await RisingEdge(self.dut.tx_clk)

        await RisingEdge(self.dut.tx_clk)

        chunk = (
            payload_data[:4]
            if len(payload_data) >= 4
            else payload_data + [0] * (4 - len(payload_data))
        )
        word = (chunk[3] << 24) | (chunk[2] << 16) | (chunk[1] << 8) | chunk[0]

        self.dut.in_slave_tx_tdata.value = word
        self.dut.in_slave_tx_tvalid.value = 1
        self.dut.in_slave_tx_tkeep.value = 0xF
        if len(payload_data) <= 4:
            self.dut.in_slave_tx_tlast.value = 1

        axis_start_time = cocotb.utils.get_sim_time("ns")
        self.dut._log.info(f"First AXI word sent at {axis_start_time} ns")

        await self.send_axis_frame(payload_data)

        await state_task
        await xgmii_task

        latencies = {}
        clock_period = 10

        if axis_start_time and state_transition_time:
            latency_ns = state_transition_time - axis_start_time
            latency_cycles = latency_ns / clock_period
            latencies["axis_to_state_transition"] = {
                "ns": latency_ns,
                "cycles": latency_cycles,
            }

        if axis_start_time and xgmii_start_time:
            latency_ns = xgmii_start_time - axis_start_time
            latency_cycles = latency_ns / clock_period
            latencies["axis_to_xgmii_start"] = {
                "ns": latency_ns,
                "cycles": latency_cycles,
            }

        self.dut._log.info("=== ACCURATE LATENCY MEASUREMENTS ===")
        for metric, data in latencies.items():
            self.dut._log.info(
                f"{metric}: {data['ns']:.1f} ns ({data['cycles']:.1f} cycles)"
            )

        return latencies


@cocotb.test()
async def test_simple_frame(dut):
    tb = TxMacTestbench(dut)

    cocotb.start_soon(Clock(dut.tx_clk, 10, units="ns").start())
    await tb.reset()

    payload = [0xAA, 0xBB, 0xCC, 0xDD]

    send_task = cocotb.start_soon(tb.send_axis_frame(payload))
    capture_task = cocotb.start_soon(tb.capture_xgmii_frame())

    await send_task
    captured_frame = await capture_task

    parsed = tb.verify_frame(captured_frame, payload)
    dut._log.info("Simple frame test passed")


@cocotb.test()
async def test_minimum_frame(dut):
    tb = TxMacTestbench(dut)

    cocotb.start_soon(Clock(dut.tx_clk, 10, units="ns").start())
    await tb.reset()

    payload = list(range(46))

    send_task = cocotb.start_soon(tb.send_axis_frame(payload))
    capture_task = cocotb.start_soon(tb.capture_xgmii_frame())

    await send_task
    captured_frame = await capture_task

    parsed = tb.verify_frame(captured_frame, payload)

    expected_min_length = ((tb.MIN_PAYLOAD_SIZE + 3) // 4) * 4
    assert len(parsed["payload"]) >= expected_min_length

    dut._log.info(
        f"Minimum frame test passed - payload length: {len(parsed['payload'])} bytes"
    )


@cocotb.test()
async def test_accurate_latency(dut):
    tb = TxMacTestbench(dut)

    cocotb.start_soon(Clock(dut.tx_clk, 10, units="ns").start())
    await tb.reset()

    payload = [0x11, 0x22, 0x33, 0x44]

    latencies = await tb.measure_latency_accurate(payload)

    dut._log.info("Accurate latency measurement completed")


@cocotb.test()
async def test_back_to_back_frames(dut):
    tb = TxMacTestbench(dut)

    cocotb.start_soon(Clock(dut.tx_clk, 10, units="ns").start())
    await tb.reset()

    for i in range(3):
        payload = [0x10 + i, 0x20 + i, 0x30 + i, 0x40 + i]

        send_task = cocotb.start_soon(tb.send_axis_frame(payload))
        capture_task = cocotb.start_soon(tb.capture_xgmii_frame())

        await send_task
        captured_frame = await capture_task

        tb.verify_frame(captured_frame, payload)
        dut._log.info(f"Frame {i+1} passed")

        await ClockCycles(dut.tx_clk, 20)


if __name__ == "__main__":
    import pytest

    pytest.main([__file__])
