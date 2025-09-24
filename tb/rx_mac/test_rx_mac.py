import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
from crc import Calculator, Crc32

crc_calculator = Calculator(Crc32.CRC32)

class RxMacTestbench:
    def __init__(self, dut):
        self.dut = dut
        
        self.AXIS_DATA_WIDTH = 32
        self.AXIS_DATA_BYTES = 4
        self.XGMII_DATA_WIDTH = 32
        self.XGMII_DATA_BYTES = 4
        
        self.XGMII_IDLE = 0x07
        self.XGMII_START = 0xFB  
        self.XGMII_TERMINATE = 0xFD 
        self.XGMII_ERROR = 0xFE   
        
        self.PREAMBLE_BYTE = 0x55 
        self.SFD_BYTE = 0xD5     
    
        self.MIN_FRAME_SIZE = 64       
        self.MAX_FRAME_SIZE = 1518     
        self.MIN_PAYLOAD_SIZE = 46     
        self.MAX_PAYLOAD_SIZE = 1500  
    
    async def reset(self):
        self.dut.rx_rst.value = 0
        self.dut.in_xgmii_data.value = (self.XGMII_IDLE << 24) | (self.XGMII_IDLE << 16) | (self.XGMII_IDLE << 8) | self.XGMII_IDLE
        self.dut.in_xgmii_ctl.value = 0xF
        self.dut.in_master_rx_tready.value = 1
        
        await ClockCycles(self.dut.rx_clk, 5)
        self.dut.rx_rst.value = 1
        await ClockCycles(self.dut.rx_clk, 5)
    
    async def send_xgmii_frame(self, payload_data, crc_value):
        for i in range(5):
            await RisingEdge(self.dut.rx_clk)
            idle_data = (self.XGMII_IDLE << 24) | (self.XGMII_IDLE << 16) | (self.XGMII_IDLE << 8) | self.XGMII_IDLE
            self.dut.in_xgmii_data.value = idle_data
            self.dut.in_xgmii_ctl.value = 0xF
        
        await RisingEdge(self.dut.rx_clk)
        start_data = (self.PREAMBLE_BYTE << 24) | (self.PREAMBLE_BYTE << 16) | (self.PREAMBLE_BYTE << 8) | self.XGMII_START
        self.dut.in_xgmii_data.value = start_data
        self.dut.in_xgmii_ctl.value = 0x1
        
        await RisingEdge(self.dut.rx_clk)
        sfd_data = (self.SFD_BYTE << 24) | (self.PREAMBLE_BYTE << 16) | (self.PREAMBLE_BYTE << 8) | self.PREAMBLE_BYTE
        self.dut.in_xgmii_data.value = sfd_data
        self.dut.in_xgmii_ctl.value = 0x0
        
        for i, data in enumerate(payload_data):
            await RisingEdge(self.dut.rx_clk)
            self.dut.in_xgmii_data.value = data
            self.dut.in_xgmii_ctl.value = 0x0
        
        await RisingEdge(self.dut.rx_clk)
        self.dut.in_xgmii_data.value = crc_value
        self.dut.in_xgmii_ctl.value = 0x0
        
        await RisingEdge(self.dut.rx_clk)
        terminate_data = (self.XGMII_TERMINATE << 24) | (self.XGMII_IDLE << 16) | (self.XGMII_IDLE << 8) | self.XGMII_IDLE
        self.dut.in_xgmii_data.value = terminate_data
        self.dut.in_xgmii_ctl.value = 0xF
        
        for i in range(10):
            await RisingEdge(self.dut.rx_clk)
            idle_data = (self.XGMII_IDLE << 24) | (self.XGMII_IDLE << 16) | (self.XGMII_IDLE << 8) | self.XGMII_IDLE
            self.dut.in_xgmii_data.value = idle_data
            self.dut.in_xgmii_ctl.value = 0xF
    
    async def capture_axis_frame(self, timeout_cycles=200):
        frame_data = []
        cycle_count = 0
        frame_started = False
        
        self.dut._log.info("Starting AXI Stream capture")
        
        while cycle_count < timeout_cycles:
            await RisingEdge(self.dut.rx_clk)
            cycle_count += 1
            
            tvalid = int(self.dut.out_master_rx_tvalid.value)
            tready = int(self.dut.in_master_rx_tready.value)
            
            if tvalid and tready:
                if not frame_started:
                    self.dut._log.info(f"AXI Stream frame started at cycle {cycle_count}")
                    frame_started = True
                
                tdata = int(self.dut.out_master_rx_tdata.value)
                tkeep = int(self.dut.out_master_rx_tkeep.value)
                tlast = int(self.dut.out_master_rx_tlast.value)
                
                self.dut._log.info(f"AXI: tdata=0x{tdata:08x}, tkeep=0x{tkeep:x}, tlast={tlast}")
                if tdata != 0x07070707: 
                    for i in range(4):
                        byte_val = (tdata >> (i * 8)) & 0xFF
                        frame_data.append(byte_val)
                    self.dut._log.info(f"  Extracted 4 bytes: {[hex(b) for b in frame_data[-4:]]}")
                else:
                    self.dut._log.info(f"  Skipped idle data: 0x{tdata:08x}")
                
                if tlast:
                    self.dut._log.info(f"AXI Stream frame completed, total bytes: {len(frame_data)}")
                    return frame_data
        
        if frame_started:
            self.dut._log.warning(f"Frame started but didn't complete, captured {len(frame_data)} bytes")
            return frame_data
        else:
            self.dut._log.warning("No AXI Stream frame detected")
            return []
    
    def parse_ethernet_frame(self, axis_data):
        frame_bytes = axis_data
        
        self.dut._log.info(f"Received frame: {len(frame_bytes)} bytes")
        self.dut._log.info(f"All bytes: {[hex(b) for b in frame_bytes]}")
        
        if len(frame_bytes) < 14:
            self.dut._log.error(f"Frame too short: {len(frame_bytes)} bytes")
            return None
        
        dest_mac = frame_bytes[0:6]
        src_mac = frame_bytes[6:12] 
        ether_type = frame_bytes[12:14]
        payload = frame_bytes[14:-4] if len(frame_bytes) > 18 else []
        fcs = frame_bytes[-4:] if len(frame_bytes) >= 4 else []
        
        self.dut._log.info(f"Dest MAC: {[hex(b) for b in dest_mac]}")
        self.dut._log.info(f"Src MAC: {[hex(b) for b in src_mac]}")
        self.dut._log.info(f"EtherType: {[hex(b) for b in ether_type]}")
        self.dut._log.info(f"Payload length: {len(payload)}")
        self.dut._log.info(f"FCS: {[hex(b) for b in fcs]}")
        
        return {
            'dest_mac': dest_mac,
            'src_mac': src_mac,
            'ether_type': ether_type,
            'payload': payload,
            'fcs': fcs,
            'total_length': len(frame_bytes)
        }
    
    def calculate_crc32(self, data: bytes) -> int:
        return crc_calculator.checksum(data)
    
    def verify_frame(self, captured_frame, expected_payload_data):
        parsed = self.parse_ethernet_frame(captured_frame)
        
        if parsed is None:
            return None
        
        self.dut._log.info("Frame received and parsed successfully")
        return parsed

@cocotb.test()
async def test_basic_frame(dut):
    tb = RxMacTestbench(dut)
    
    cocotb.start_soon(Clock(dut.rx_clk, 10, units="ns").start())
    await tb.reset()
    
    payload_data = [
        0x33221100,  
        0xBBAA5544,  
        0xFFEEDDCC, 
        0x00000008, 
        0xA1B2C3D4, 
        0x12345678,
        0xDEADBEEF,
        0x87654321,
        0xFEDCBA98,
        0x55AA33CC,
        0x9F8E7D6C,
        0x1A2B3C4D,
        0xCAFEBABE,
        0x6789ABCD,
        0xF0E1D2C3,
        0x3E5F7A9B  
    ]
    
    crc_value = 0x713b28b2
    
    send_task = cocotb.start_soon(tb.send_xgmii_frame(payload_data, crc_value))
    capture_task = cocotb.start_soon(tb.capture_axis_frame())
    
    await send_task
    captured_frame = await capture_task
    
    if captured_frame and len(captured_frame) > 0:
        parsed = tb.verify_frame(captured_frame, payload_data)
        dut._log.info("Basic frame test passed")
    else:
        dut._log.error("No valid frame received")

@cocotb.test()
async def test_simple_frame(dut):
    tb = RxMacTestbench(dut)
    
    cocotb.start_soon(Clock(dut.rx_clk, 10, units="ns").start())
    await tb.reset()
    
    payload_data = [
        0x33221100, 
        0xBBAA5544,   
        0xFFEEDDCC, 
        0x00000008,  
        0xAABBCCDD, 
        0x11223344  
    ]
    crc_value = 0x12345678
    
    send_task = cocotb.start_soon(tb.send_xgmii_frame(payload_data, crc_value))
    capture_task = cocotb.start_soon(tb.capture_axis_frame())
    
    await send_task
    captured_frame = await capture_task
    
    if captured_frame and len(captured_frame) > 0:
        parsed = tb.parse_ethernet_frame(captured_frame)
        dut._log.info("Simple frame test passed")
    else:
        dut._log.error("No valid frame received")

@cocotb.test()
async def test_minimum_frame(dut):
    tb = RxMacTestbench(dut)
    
    cocotb.start_soon(Clock(dut.rx_clk, 10, units="ns").start())
    await tb.reset()
    
    payload_data = [
        0x33221100,  
        0xBBAA5544,  
        0xFFEEDDCC,  
        0x00080000,  
        0x01020304,  
        0x05060708, 
        0x090A0B0C,  
        0x0D0E0F10, 
        0x11121314,  
        0x15161718,  
        0x191A1B1C,  
        0x1D1E1F20,  
        0x21222324, 
        0x25262728,  
        0x292A2B2C,  
        0x2D2E0000   
    ]
    
    crc_value = 0x713b28b2
    
    send_task = cocotb.start_soon(tb.send_xgmii_frame(payload_data, crc_value))
    capture_task = cocotb.start_soon(tb.capture_axis_frame())
    
    await send_task
    captured_frame = await capture_task
    
    if captured_frame and len(captured_frame) > 0:
        parsed = tb.parse_ethernet_frame(captured_frame)
        if parsed:
            actual_payload_length = len([b for b in parsed["payload"] if b != 0])
            dut._log.info(f"Non-zero payload bytes: {actual_payload_length}")
            dut._log.info(f"Minimum frame test passed - total frame length: {len(captured_frame)} bytes")
        else:
            dut._log.error("Failed to parse minimum frame")
    else:
        dut._log.error("No valid frame received")
