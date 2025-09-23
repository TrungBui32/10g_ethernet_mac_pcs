import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.result import TestFailure
from cocotb.clock import Clock
from crc import Calculator, Crc32

crc32_calc = Calculator(Crc32.CRC32)

class CRC32Testbench:
    def __init__(self, dut):
        self.dut = dut
        
        self.SLICE_LENGTH = 4
        self.INITIAL_CRC = 0xFFFFFFFF
        self.INVERT_OUTPUT = 1
        self.REGISTER_OUTPUT = 1
        self.MAX_SLICE_LENGTH = 16
    
    async def reset(self): 
        self.dut.rst.value = 0
        self.dut.in_data.value = 0
        self.dut.in_valid.value = 0
        
        await ClockCycles(self.dut.clk, 5)
        self.dut.rst.value = 1
        await ClockCycles(self.dut.clk, 5)
    
    async def send_data(self, test_data, test_valid):
        for i in range(len(test_data)):  
            await RisingEdge(self.dut.clk)
            
            self.dut.in_data.value = test_data[i]
            self.dut.in_valid.value = test_valid[i]
            
            self.dut._log.info(f"Sending: data=0x{test_data[i]:08x}, valid=0x{test_valid[i]:x}")
        
        await RisingEdge(self.dut.clk)
        self.dut.in_data.value = 0
        self.dut.in_valid.value = 0
        
        await ClockCycles(self.dut.clk, 5)
    
    async def capture_crc_out(self):
        await ClockCycles(self.dut.clk, 2)  
        return self.dut.out_crc.value
    
    def calculate_crc32(self, data_list, valid_list):
        byte_data = b''
        
        for val, valid in zip(data_list, valid_list):
            if valid == 0:
                continue  
                
            val_bytes = val.to_bytes(4, 'little') 
            
            if valid == 0xF:  
                byte_data += val_bytes
            elif valid == 0x3: 
                byte_data += val_bytes[:2]
            elif valid == 0x1: 
                byte_data += val_bytes[:1]
            elif valid == 0x7: 
                byte_data += val_bytes[:3]
            else:
                num_valid_bytes = bin(valid).count('1')
                byte_data += val_bytes[:num_valid_bytes]
        
        self.dut._log.info(f"CRC input bytes: {byte_data.hex()}")
        return crc32_calc.checksum(byte_data)

@cocotb.test()
async def test_crc(dut):
    tb = CRC32Testbench(dut)
    
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    await tb.reset()
    
    test_value = [0x33221100, 0xBBAA5544, 0xFFEEDDCC, 0x00000008, 
                  0xA1B2C3D4, 0x12345678, 0xDEADBEEF, 0x87654321,
                  0xFEDCBA98, 0x55AA33CC, 0x9F8E7D6C, 0x1A2B3C4D,
                  0xCAFEBABE, 0x6789ABCD, 0xF0E1D2C3, 0x3E5F7A9B]
                  
    test_valid = [0xF, 0xF, 0xF, 0x3, 0xF, 0xF, 0xF, 0xF,
                  0xF, 0xF, 0xF, 0xF, 0xF, 0xF, 0xF, 0xF]
    
    await tb.send_data(test_value, test_valid)
    final_crc = await tb.capture_crc_out()
    
    expected_crc = tb.calculate_crc32(test_value, test_valid)
    
    dut._log.info(f"Final CRC: 0x{int(final_crc):08x}")
    dut._log.info(f"Expected CRC: 0x{expected_crc:08x}")
    
    assert int(final_crc) == expected_crc, f"CRC mismatch: got 0x{int(final_crc):08x}, expected 0x{expected_crc:08x}"

@cocotb.test()
async def test_simple_crc_debug(dut):
    tb = CRC32Testbench(dut)
    
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await tb.reset()
    
    test_value = [0x12345678]
    test_valid = [0xF]
    
    await tb.send_data(test_value, test_valid)
    final_crc = await tb.capture_crc_out()
    
    data_le = test_value[0].to_bytes(4, 'little')
    data_be = test_value[0].to_bytes(4, 'big')
    
    crc_le = crc32_calc.checksum(data_le)
    crc_be = crc32_calc.checksum(data_be)
    
    dut._log.info(f"Hardware CRC: 0x{int(final_crc):08x}")
    dut._log.info(f"SW CRC (LE): 0x{crc_le:08x}")
    dut._log.info(f"Input data: 0x{test_value[0]:08x}")
    dut._log.info(f"Bytes (LE): {data_le.hex()}")
