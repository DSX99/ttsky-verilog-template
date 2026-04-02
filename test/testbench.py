import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random
from fastecdsa.curve import Curve

async def set_spi_inputs(dut, cs, sclk, mosi):
    val = 0
    if cs:   val |= (1 << 0)
    if sclk: val |= (1 << 1)
    if mosi: val |= (1 << 2)
    dut.ui_in.value = val

@cocotb.test()
async def full_tb(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.ena.value = 1
    
    p = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDC7
    a = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDC4
    b = 0x00E8C2505DEDFC86DDC1BD0B2B6667F1DA34B82574761CB0E879BD081CFD0B6265EE3CB090F30D27614CB4574010DA90DD862EF9D4EBEE4761503190785A71C760
    q = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF27E69532F48D89116FF22B8D4E0560609B4B38ABFAD2B85DCACDB1411F10B275
    gx, gy = 0x03, 0x7503CFE87A836AE3A61B8816E25450E6CE5E1C93ACF1ABC1778064FDCBEFA921DF1626BE4FD036E93D75E6A50E3A41E98028FE5FC235F5B889A589CB5215F2A4
    
    curve = Curve('gost_512', p, a, b, q, gx, gy)
    G = curve.G

    for iteration in range(5):
        dut._log.info(f"--- Starting Iteration {iteration} ---")

        dut.rst_n.value = 0      
        dut.ui_in.value = 0      
        await Timer(50, "ns")    
        dut.rst_n.value = 1     
        await RisingEdge(dut.clk)
        await Timer(10, "ns")

        k = random.randint(1, q-1)
        spi_send = ((G.x*(1<<512))%p) + (((G.y*(1<<512))%p)<<512) + (((a*(1<<512))%p)<<1024) + (p<<1536) + (k<<2048)
        
        await set_spi_inputs(dut, cs=1, sclk=0, mosi=0)
        await Timer(20, "ns")
        
        for _ in range(2560):
            mosi_bit = spi_send & 1
            await set_spi_inputs(dut, cs=1, sclk=0, mosi=mosi_bit)
            await Timer(5, "ns")
            await set_spi_inputs(dut, cs=1, sclk=1, mosi=mosi_bit)
            await Timer(5, "ns")
            spi_send >>= 1
        
        await set_spi_inputs(dut, cs=0, sclk=0, mosi=0)

        while (dut.uo_out.value.integer & 0x01) == 0:
            await RisingEdge(dut.clk)
        
        got_x = 0
        for i in range(512):
            await set_spi_inputs(dut, cs=0, sclk=1, mosi=0)
            await Timer(5, "ns")
            bit = (dut.uo_out.value.integer >> 1) & 1
            got_x |= (bit << i)
            await set_spi_inputs(dut, cs=0, sclk=0, mosi=0)
            await Timer(5, "ns")

        got_y = 0
        for i in range(512):
            await set_spi_inputs(dut, cs=0, sclk=1, mosi=0)
            await Timer(5, "ns")
            bit = (dut.uo_out.value.integer >> 1) & 1
            got_y |= (bit << i)
            await set_spi_inputs(dut, cs=0, sclk=0, mosi=0)
            await Timer(5, "ns")

        expected_P = k * G
        assert got_x == expected_P.x and got_y == expected_P.y, \
            f"FAIL: Iteration {iteration}\nExp X: {hex(expected_P.x)}\nGot X: {hex(got_x)}"
        
        dut._log.info(f"PASS: Iteration {iteration} matches fastecdsa!")