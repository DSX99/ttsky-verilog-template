import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.utils import get_sim_time
from cocotb.clock import Clock
import random
from fastecdsa.curve import Curve
from fastecdsa.point import Point
import numpy as np

#256 bit

WIDTH =256

p = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD97
a = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD94
b = 0xA6
m = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6C611070995AD10045841B09B761B893
q = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6C611070995AD10045841B09B761B893
x = 0x01
y = 0x008D91E471E0989CDA27DF505A453F2B7635294F2DDF23E3B122ACC99C9E9F1E14
gost_256_paramA = Curve(
    'id-tc26-gost-3410-12-256-paramSetA', 
    p, a, b, q, x, y
)

G = gost_256_paramA.G


def inverse(a,p):
    return pow(a,p-2,p)

@cocotb.test()
async def full_tb(dut):
    
    cocotb.start_soon(Clock(dut.clk, 1, unit="ns").start())
    
    for i in range(0,5):
        print(i)
        
        k = random.randint(0,q-1)
        
        await RisingEdge(dut.clk)
        dut.rst_n.value=0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value=1
        await RisingEdge(dut.clk)
        
        # k=(1<<WIDTH)-q
            
        spi_send = ((G.x*(1<<WIDTH))%p) + (((G.y*(1<<WIDTH))%p)<<WIDTH) + (((a*(1<<WIDTH))%p)<<(WIDTH*2)) + (p<<(WIDTH*3)) + (k<<(WIDTH*4))
        
        ui_in=1
        
        for j in range(0,WIDTH*5):
            ui_in= 1 + (1<<1) + ((spi_send&1) <<2)
            dut.ui_in.value=ui_in
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            ui_in= 1 + (0<<1) + ((spi_send&1)<<2)
            dut.ui_in.value=ui_in
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            spi_send=spi_send>>1
            
        for j in range(2):
            dut.ui_in.value=3
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            dut.ui_in.value=1
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
        
        start_time = get_sim_time(unit='ns')
        
        dut.ui_in.value=0
        
        while (int(dut.uo_out.value)&1)!=1:
            await RisingEdge(dut.clk)
            
        end_time = get_sim_time(unit='ns')
            
        await RisingEdge(dut.clk)
        
        got_x=0
        for i in range(0,WIDTH):
            ui_in= 1<<1
            dut.ui_in.value=ui_in
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            ui_in= 0<<1
            dut.ui_in.value=ui_in
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            got_bit = (int(dut.uo_out.value)>>1)&1
            got_x=(got_x>>1)+(got_bit<<(WIDTH-1))
            
        
        got_y=0
        for i in range(0,WIDTH):
            ui_in= 1<<1
            dut.ui_in.value=ui_in
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            ui_in= 0<<1
            dut.ui_in.value=ui_in
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            got_bit = (int(dut.uo_out.value)>>1)&1
            got_y=(got_y>>1)+(got_bit<<(WIDTH-1))
            
        P=k*G
        
        assert P.x == got_x and P.y == got_y, f"error P={P.x,P.y}, got = {got_x,got_y}"
        print(f"time {end_time-start_time}")