import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random
from fastecdsa.curve import Curve
from fastecdsa.point import Point

def inverse(a,p):
    return pow(a,p-2,p)

@cocotb.test()
async def full_tb(dut):
    
    cocotb.start_soon(Clock(dut.clk, 1, unit="ns").start())

    p = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD97
    a = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD94
    b = 0xA6
    m = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6C611070995AD10045841B09B761B893
    q = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6C611070995AD10045841B09B761B893
    x = 0x01
    y = 0x008D91E471E0989CDA27DF505A453F2B7635294F2DDF23E3B122ACC99C9E9F1E14
    
    gost_256_paramB = Curve(
        'id-tc26-gost-3410-2012-256-paramSetB', 
        p, a, b, q, x, y
    )
    
    G = gost_256_paramB.G
    
    for i in range(0,5):
        print(i)
        
        width=256
        first=0
        
        c = random.randint(0,q-1)
        d = random.randint(0,q-1)
        
        P0 = 1*G
        P1 = 2*G
        
        await RisingEdge(dut.clk)
        dut.rst_n.value=0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value=1
        await RisingEdge(dut.clk)
            
        spi_send = ((P0.x*(1<<width))%p) + (((P0.y*(1<<width))%p)<<width) + (((1*(1<<width))%p)<<(width*2)) + (((P1.x*(1<<width))%p)<<(width*3)) + (((P1.y*(1<<width))%p)<<(width*4)) + (((1*(1<<width))%p)<<(width*5)) + (((a*(1<<width))%p)<<(width*6)) + ((p)<<(width*7)) + (first << (width*8))
        
        ui_in=1
        
        for j in range(0,width*8+1):
            ui_in= 1 + (1<<1) + ((spi_send&1) <<2)
            dut.ui_in.value=ui_in
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            ui_in= 1 + (0<<1) + ((spi_send&1)<<2)
            dut.ui_in.value=ui_in
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            spi_send=spi_send>>1
            
        for j in range(0,random.randint(1,100)):
            ui_in= 1 + 1<<1
            dut.ui_in.value=ui_in
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            ui_in= 1 + 0<<1
            dut.ui_in.value=ui_in
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
        
        ui_in=0
        dut.ui_in.value=ui_in
        
        while (int(dut.uo_out.value)&1)!=1:
            await RisingEdge(dut.clk)
            
        await RisingEdge(dut.clk)
        
        got_x_dub=0
        for i in range(0,width):
            ui_in= 1<<1
            dut.ui_in.value=ui_in
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            ui_in= 0<<1
            dut.ui_in.value=ui_in
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            got_bit = (int(dut.uo_out.value)>>1)&1
            got_x_dub=(got_x_dub>>1)+(got_bit<<(width-1))
            
        
        got_y_dub=0
        for i in range(0,width):
            ui_in= 1<<1
            dut.ui_in.value=ui_in
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            ui_in= 0<<1
            dut.ui_in.value=ui_in
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            got_bit = (int(dut.uo_out.value)>>1)&1
            got_y_dub=(got_y_dub>>1)+(got_bit<<(width-1))
            
        got_z_dub=0
        for i in range(0,width):
            ui_in= 1<<1
            dut.ui_in.value=ui_in
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            ui_in= 0<<1
            dut.ui_in.value=ui_in
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            got_bit = (int(dut.uo_out.value)>>1)&1
            got_z_dub=(got_z_dub>>1)+(got_bit<<(width-1))
            
        
        got_x_sum=0
        for i in range(0,width):
            ui_in= 1<<1
            dut.ui_in.value=ui_in
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            ui_in= 0<<1
            dut.ui_in.value=ui_in
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            got_bit = (int(dut.uo_out.value)>>1)&1
            got_x_sum=(got_x_sum>>1)+(got_bit<<(width-1))
            
        got_y_sum=0
        for i in range(0,width):
            ui_in= 1<<1
            dut.ui_in.value=ui_in
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            ui_in= 0<<1
            dut.ui_in.value=ui_in
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            got_bit = (int(dut.uo_out.value)>>1)&1
            got_y_sum=(got_y_sum>>1)+(got_bit<<(width-1))
            
        
        got_z_sum=0
        for i in range(0,width):
            ui_in= 1<<1
            dut.ui_in.value=ui_in
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            ui_in= 0<<1
            dut.ui_in.value=ui_in
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            got_bit = (int(dut.uo_out.value)>>1)&1
            got_z_sum=(got_z_sum>>1)+(got_bit<<(width-1))
            
        r=1<<256
        r_inv = inverse(r,p)
        got_x_dub=(got_x_dub*r_inv)%p
        got_y_dub=(got_y_dub*r_inv)%p
        got_z_dub=(got_z_dub*r_inv)%p
        got_x_sum=(got_x_sum*r_inv)%p
        got_y_sum=(got_y_sum*r_inv)%p
        got_z_sum=(got_z_sum*r_inv)%p
          
        z_dub = inverse(got_z_dub,p)
        x_dub = (got_x_dub * z_dub**2)%p
        y_dub = (got_y_dub * z_dub**3)%p
        
        z_sum = inverse(got_z_sum,p)
        x_sum = (got_x_sum * z_sum**2)%p
        y_sum = (got_y_sum * z_sum**3)%p
        
        P_sum = P0+P1
        P_dub = P0+P0
        
        assert P_dub.x == x_dub and P_dub.y == y_dub, f"error in dub P={P_dub.x,P_dub.y}, got = {x_dub,y_dub}"
        assert P_sum.x == x_sum and P_sum.y == y_sum, f"error in sum P={P_sum.x,P_sum.y}, got = {x_sum,y_sum}"
