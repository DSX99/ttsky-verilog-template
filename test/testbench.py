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
    
    WIDTH =256
    width =256
    
    for i in range(0,10):
        print(i)
        k = random.randint(0,q-1)
        
        answ = k*G
        
        Z_sq = ((2*G.y)**2)%p
        mZ = (3*G.x**2+a)%p
        Xrp = ((mZ**2)-3*G.x*Z_sq)%p
        Y = (Z_sq**2)%p
        
        k = (k - (1<<256))%q
        
        XQP = 0
        XRP = (Xrp)%p
        M = (mZ)%p
        YP = (Y)%p
        for wid in range(256):
            await RisingEdge(dut.clk)
            dut.rst_n.value=0
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            dut.rst_n.value=1
            await RisingEdge(dut.clk)
                
            bit = (k >> (255 - wid)) & 1
            if bit:
                spi_send = (XQP) + (XRP<<WIDTH) + (M<<(2*WIDTH)) + (YP<<(3*WIDTH)) + (0<<(4*WIDTH)) + (0<<(5*WIDTH)) + (0<<(6*WIDTH)) + (0<<(7*WIDTH)) + (0<<(8*WIDTH)) + (p<<(9*WIDTH))
            else:
                spi_send = (XRP) + (XQP<<WIDTH) + (M<<(2*WIDTH)) + (YP<<(3*WIDTH)) + (0<<(4*WIDTH)) + (0<<(5*WIDTH)) + (0<<(6*WIDTH)) + (0<<(7*WIDTH)) + (0<<(8*WIDTH)) + (p<<(9*WIDTH))
            
            ui_in=1
            
            for j in range(width*10):
                ui_in= 1 + (1<<1) + ((spi_send&1) <<2)
                dut.ui_in.value=ui_in
                await RisingEdge(dut.clk)
                await RisingEdge(dut.clk)
                ui_in= 1 + (0<<1) + ((spi_send&1)<<2)
                dut.ui_in.value=ui_in
                await RisingEdge(dut.clk)
                await RisingEdge(dut.clk)
                spi_send=spi_send>>1
                
            for j in range(random.randint(100,1000)):
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
            
            mem=[]
            for j in range(0,10):
                mem.append(0)
                for i in range(width):
                    ui_in= 1<<1
                    dut.ui_in.value=ui_in
                    await RisingEdge(dut.clk)
                    await RisingEdge(dut.clk)
                    ui_in= 0<<1
                    dut.ui_in.value=ui_in
                    await RisingEdge(dut.clk)
                    await RisingEdge(dut.clk)
                    got_bit = (int(dut.uo_out.value)>>1)&1
                    mem[j]=(mem[j]>>1)+(got_bit<<(width-1))
                
            if bit:
                XQP = mem[6]
                XRP = mem[5]
                M = mem[7]
                YP = mem[4]
            else:
                XRP = mem[6]
                XQP = mem[5]
                M = mem[7]
                YP = mem[4]
            
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            
            
        YP_demont = YP%p
        M_demont = M%p
        XQP_demont = XQP%p
        XRP_demont = XRP%p
                
        # print(hex(XQP),hex(XRP),hex(M),hex(YP))
                
        numer = (2*G.y*(M_demont**2 - XQP_demont - XRP_demont))%p
        denom = (3*G.x * (YP_demont))%p
                
        Z_inv = ((numer)*inverse(denom,p))%p

        x_q = (G.x + (XQP_demont)*Z_inv*Z_inv)%p
        
        assert answ.x == x_q, f"error answ={hex(answ.x)}, got = {hex(x_q)}"
    print(f"PASS")
