import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.utils import get_sim_time
from cocotb.clock import Clock
import random
from fastecdsa.curve import Curve
from fastecdsa.point import Point
import numpy as np

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

async def operation_timed(dut ,first, second, operation, return_index, times):
    await RisingEdge(dut.clk)
    dut.rst_n.value=0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value=1
    await RisingEdge(dut.clk)
    
    spi_send = (first) + (second<<WIDTH) + (0<<(2*WIDTH)) + (0<<(3*WIDTH)) + (0<<(4*WIDTH)) + (0<<(5*WIDTH)) + (0<<(6*WIDTH)) + (0<<(7*WIDTH)) + (0<<(8*WIDTH)) + (p<<(9*WIDTH))

    ui_in=1 + (operation<<3)
            
    for j in range(WIDTH*10):
        ui_in= 1 + (1<<1) + ((spi_send&1) <<2) + (operation<<3)
        dut.ui_in.value=ui_in
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        ui_in= 1 + (0<<1) + ((spi_send&1)<<2) + (operation<<3)
        dut.ui_in.value=ui_in
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        spi_send=spi_send>>1
        
    dut.ui_in.value=3 + (operation<<3)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.ui_in.value=1 + (operation<<3)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    start_time = get_sim_time(unit='ns')
    
    dut.ui_in.value=(operation<<3)
    
    while (int(dut.uo_out.value)&1)!=1:
        await RisingEdge(dut.clk)
    
    end_time = get_sim_time(unit='ns')
    
    await RisingEdge(dut.clk)
    
    mem=[]
    
    for j in range(0,10):
        mem.append(0)
        for i in range(WIDTH):
            ui_in= 1<<1
            dut.ui_in.value=ui_in
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            ui_in= 0<<1
            dut.ui_in.value=ui_in
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            got_bit = (int(dut.uo_out.value)>>1)&1
            mem[j]=(mem[j]>>1)+(got_bit<<(WIDTH-1))
    
    times.append(np.round(end_time-start_time))
    
    return mem[return_index]

@cocotb.test()
async def full_tb(dut):
    
    cocotb.start_soon(Clock(dut.clk, 1, unit="ns").start())
    
    for i in range(0,5):
        times=[]
        times_inv=[]
        times_prep=[]
        print(i)
        k = random.randint(0,q-1)
        
        answ = k*G
        
        double_G_y= await operation_timed(dut,G.y,G.y,2,2,times_prep)
        assert double_G_y == ((2*G.y)%p) , "error in double_G_y"
        
        Z_sq = await operation_timed(dut,double_G_y,double_G_y,1,2,times_prep)
        assert Z_sq == (((2*G.y)**2)%p) , "error in Z_sq"
        
        double_G_x = await operation_timed(dut,G.x,G.x,2,2,times_prep)
        assert double_G_x == ((2*G.x)%p) , "error in double_G_x"
        
        triple_G_x = await operation_timed(dut,double_G_x,G.x,2,2,times_prep)
        assert triple_G_x == ((3*G.x)%p) , "error in triple_G_x_sq"
        
        triple_G_x_sq = await operation_timed(dut,triple_G_x,G.x,1,2,times_prep)
        assert triple_G_x_sq == ((3*G.x**2)%p) , "error in G_x_sq"
        
        mZ = await operation_timed(dut,triple_G_x_sq,a,2,2,times_prep)
        assert mZ == ((3*G.x**2+a)%p) , "error in mZ"
        
        mZ_sq = await operation_timed(dut,mZ,mZ,1,2,times_prep)
        assert mZ_sq == ((mZ**2)%p) , "error in mZ_sq"
        
        G_x_Z_sq = await operation_timed(dut,G.x,Z_sq,1,2,times_prep)
        assert G_x_Z_sq == ((G.x*Z_sq)%p) , "error in G_x_Z_sq"
        
        double_G_x_Z_sq = await operation_timed(dut,G_x_Z_sq,G_x_Z_sq,2,2,times_prep)
        assert double_G_x_Z_sq == ((2*G.x*Z_sq)%p) , "error in double_G_x_Z_sq"
        
        triple_G_x_Z_sq = await operation_timed(dut,double_G_x_Z_sq,G_x_Z_sq,2,2,times_prep)
        assert triple_G_x_Z_sq == ((3*G.x*Z_sq)%p) , "error in triple_G_x_Z_sq"
        
        Xrp = await operation_timed(dut,mZ_sq,triple_G_x_Z_sq,3,2,times_prep)
        assert Xrp == (((mZ**2)-3*G.x*Z_sq)%p) , "error in Xrp"
        
        Y = await operation_timed(dut, Z_sq, Z_sq, 1, 2,times_prep)
        assert Y == ((Z_sq**2)%p), "error in Y"
        
        k = (k - (1<<WIDTH))%q
        
        XQP = 0
        XRP = Xrp
        M = mZ
        YP = Y
        
        for wid in range(WIDTH):
            if (not wid%32):
                print(wid)
            await RisingEdge(dut.clk)
            dut.rst_n.value=0
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            dut.rst_n.value=1
            await RisingEdge(dut.clk)
            
            bit = (k >> (WIDTH - 1 - wid)) & 1
            if bit:
                spi_send = (XQP) + (XRP<<WIDTH) + (M<<(2*WIDTH)) + (YP<<(3*WIDTH)) + (0<<(4*WIDTH)) + (0<<(5*WIDTH)) + (0<<(6*WIDTH)) + (0<<(7*WIDTH)) + (0<<(8*WIDTH)) + (p<<(9*WIDTH))
            else:
                spi_send = (XRP) + (XQP<<WIDTH) + (M<<(2*WIDTH)) + (YP<<(3*WIDTH)) + (0<<(4*WIDTH)) + (0<<(5*WIDTH)) + (0<<(6*WIDTH)) + (0<<(7*WIDTH)) + (0<<(8*WIDTH)) + (p<<(9*WIDTH))
            
            operation=0
            
            ui_in=1 + (operation<<3)
            
            for j in range(WIDTH*10):
                ui_in= 1 + (1<<1) + ((spi_send&1) <<2) + (operation<<3)
                dut.ui_in.value=ui_in
                await RisingEdge(dut.clk)
                await RisingEdge(dut.clk)
                ui_in= 1 + (0<<1) + ((spi_send&1)<<2) + (operation<<3)
                dut.ui_in.value=ui_in
                await RisingEdge(dut.clk)
                await RisingEdge(dut.clk)
                spi_send=spi_send>>1    
                
            dut.ui_in.value=3 + (operation<<3)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            dut.ui_in.value=1 + (operation<<3)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
                
            start_time = get_sim_time(unit='ns')
            
            dut.ui_in.value=(operation<<3)
            
            while (int(dut.uo_out.value)&1)!=1:
                await RisingEdge(dut.clk)
                
            end_time = get_sim_time(unit='ns')
                
            await RisingEdge(dut.clk)
            
            mem=[]
            
            for j in range(0,10):
                mem.append(0)
                for i in range(WIDTH):
                    ui_in= 1<<1
                    dut.ui_in.value=ui_in
                    await RisingEdge(dut.clk)
                    await RisingEdge(dut.clk)
                    ui_in= 0<<1
                    dut.ui_in.value=ui_in
                    await RisingEdge(dut.clk)
                    await RisingEdge(dut.clk)
                    got_bit = (int(dut.uo_out.value)>>1)&1
                    mem[j]=(mem[j]>>1)+(got_bit<<(WIDTH-1))
            
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
                
            times.append(np.round(end_time-start_time))
            
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
            
        M_sq = await operation_timed(dut, M, M, 1, 2,times_prep)
        assert M_sq == ((M**2)%p), "error in M_sq"

        M_sq_XQP = await operation_timed(dut, M_sq, XQP, 3, 2,times_prep)
        assert M_sq_XQP == ((M_demont**2 - XQP_demont)%p), "error in M_sq_XQP"
        
        M_sq_XQP_XRP = await operation_timed(dut, M_sq_XQP, XRP, 3, 2,times_prep)
        assert M_sq_XQP_XRP == ((M_demont**2 - XQP_demont - XRP_demont)%p), "error in M_sq_XQP_XRP"
        
        numer = await operation_timed(dut, double_G_y, M_sq_XQP_XRP, 1, 2,times_prep)
        assert numer == (2*G.y*(M_demont**2 - XQP_demont - XRP_demont))%p , "error in numer"

        denom = await operation_timed(dut, triple_G_x, YP, 1, 2,times_prep)
        assert denom == (3*G.x * (YP_demont))%p , "error in denom"
        
        inv = 1

        for i in range(WIDTH):
            if(not i%32):
                print("inverse",i)
            bit = ((p-2)>>(WIDTH-1-i))&1
            inv = await operation_timed(dut, inv, inv, 1, 2,times_inv)
            if bit:
                inv = await operation_timed(dut, inv, denom, 1, 2, times_inv)
            else:
                await operation_timed(dut, inv, denom, 1, 2, times_inv)
                    
        assert inv == inverse(denom,p), "error in inversion"
                
        Z_inv = await operation_timed(dut, numer, inv, 1, 2,times_prep)
        assert Z_inv == ((numer)*inverse(denom,p))%p , "error in Z_inv"    
            
        Z_inv_sq = await operation_timed(dut, Z_inv, Z_inv, 1, 2,times_prep)
        assert Z_inv_sq == (Z_inv*Z_inv)%p , "error in Z_inv_sq"    

        Z_inv_sq_XQP = await operation_timed(dut, XQP, Z_inv_sq, 1, 2,times_prep)
        assert Z_inv_sq_XQP == ((XQP_demont)*Z_inv*Z_inv)%p, "error in Z_inv_sq_XQP"
        
        x_q = await operation_timed(dut, G.x, Z_inv_sq_XQP, 2, 2,times_prep)
        assert x_q == (G.x + (XQP_demont)*Z_inv*Z_inv)%p, "error in x_q"
        
        assert answ.x == x_q, f"error answ={hex(answ.x)}, got = {hex(x_q)}"
        print("ladder ",np.mean(times),(np.max(times)-np.min(times)),np.sum(times))
        print("inversion ",np.mean(times_inv),(np.max(times_inv)-np.min(times_inv)),np.sum(times_inv))
        print("prep and out",np.sum(times_prep))
        print("total time",np.sum(times)+np.sum(times_inv)+np.sum(times_prep))
        print(f"PASS")