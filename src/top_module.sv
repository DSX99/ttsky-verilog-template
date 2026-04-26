module top_module #(
    parameter WIDTH = 256
)(
    input logic cs,
    input logic spi_clk,
    input logic spi_pad_MOSI,
    input logic clk,rst,
    output logic rdy,
    output logic spi_pad_MISO
);

    logic [WIDTH:0] mid;
    logic [WIDTH-1:0] P0_x,P0_y,P0_z,P1_x,P1_y,P1_z,sum_x,sum_y,sum_z,dub_x,dub_y,dub_z,add_out;
    logic [WIDTH-1:0] a,mod,k,summed_x,summed_y,summed_z,dubbed_x,dubbed_y,dubbed_z, inv_in, inv_out, mult_a, mult_b, mult_out;
    logic [$clog2(WIDTH)+2:0] count_spi;
    logic [$clog2(WIDTH)-1:0] count;
    logic [3:0] state;
    logic req, alu_req, inv_req, alu_rdy, inv_rdy, first, mult_req, mult_rdy, start_sending, sent, alu_mult_only, did_it, prev_spi_clk;

    localparam q = 'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6C611070995AD10045841B09B761B893;

    always_comb begin
        first=0;
        sum_x=0;sum_y=0;sum_z=0;
        dub_x=0;dub_y=0;dub_z=0;
        mult_a=0;mult_b=0;
        mid=0;add_out=0;
        inv_in=0;
        alu_mult_only=0;
        spi_pad_MISO=0;
        case(state)
            0: begin
                if(req) begin
                    mid=(k+q-{1'b1,{WIDTH{1'b0}}});
                    add_out = (mid[WIDTH]) ? (mid[WIDTH-1:0]+q) : mid[WIDTH-1:0];
                end
            end
            1: begin
                first=1;
                dub_x=P1_x; dub_y=P1_y; dub_z=P1_z;
                sum_x=P0_x; sum_y=P0_y; sum_z=P0_z;
            end
            2: begin
                if(k[count]) begin
                    dub_x=P1_x; dub_y=P1_y; dub_z=P1_z;
                    sum_x=P0_x; sum_y=P0_y; sum_z=P0_z;
                end else begin
                    dub_x=P0_x; dub_y=P0_y; dub_z=P0_z;
                    sum_x=P1_x; sum_y=P1_y; sum_z=P1_z;
                end
            end
            3: begin
                alu_mult_only=1;
                sum_x=P0_x;
            end
            4: begin
                alu_mult_only=1;
                sum_x=P0_y;
            end
            5: begin
                alu_mult_only=1;
                sum_x=P0_z;
            end
            6: begin
                inv_in=P1_z;
            end
            7: begin
                mult_a= P1_z; mult_b= P1_z;
            end
            8: begin
                mult_a= P0_x; mult_b= P0_z;
            end
            9: begin
                mult_a= P1_z; mult_b= P0_z;
            end
            10: begin
                mult_a= P0_y; mult_b= P0_z;
            end
        endcase


        //spi_miso drive
        if(rdy) begin
            if(count_spi<WIDTH)begin
                spi_pad_MISO=P0_x[0];
            end else begin
                spi_pad_MISO=P0_y[0];
            end
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if(rst)begin
            P0_x<=0; P0_y<=0; P0_z<=617; P1_x<=0; P1_y<=0; P1_z<=617;
            a<=0; mod<=0; k<=0; count_spi<=0; rdy<=0; req<=0; prev_spi_clk<=0;
            state<=0; count<=0; sent<=0; start_sending<=0; did_it<=0;
        end else begin
            inv_req<=0;
            mult_req<=0;
            alu_req<=0;
            case(state)
                0: begin
                    if(req) begin
                        rdy<=0;
                        state<=1;
                        k<=add_out;
                    end
                end
                1: begin
                    if(!sent) alu_req<=1;
                    sent<=1;
                    req<=0;
                    if(alu_rdy) begin
                        P0_x<=summed_x; P0_y<=summed_y; P0_z<=summed_z;
                        P1_x<=dubbed_x; P1_y<=dubbed_y; P1_z<=dubbed_z;
                        state<=2;
                        sent<=0;
                        count<=count-1;
                    end
                end
                2: begin
                    if(!sent) begin
                        alu_req<=1;
                    end
                    sent<=1;
                    if(alu_rdy) begin
                        if(k[count]) begin
                            P0_x<=summed_x; P0_y<=summed_y; P0_z<=summed_z;
                            P1_x<=dubbed_x; P1_y<=dubbed_y; P1_z<=dubbed_z;
                        end else begin
                            P1_x<=summed_x; P1_y<=summed_y; P1_z<=summed_z;
                            P0_x<=dubbed_x; P0_y<=dubbed_y; P0_z<=dubbed_z;
                        end

                        sent<=0;
                        if(count==0 & did_it) begin
                            state<=3;
                        end else begin
                            count<=count-1;
                            did_it<=1;
                        end
                    end
                end
                3: begin
                    if(!sent) alu_req<=1;
                    sent<=1;
                    if(alu_rdy) begin
                        P0_x<=dubbed_x;
                        sent<=0;
                        state<=4;
                    end
                end
                4: begin
                    if(!sent) alu_req<=1;
                    sent<=1;
                    if(alu_rdy) begin
                        P0_y<=dubbed_x;
                        sent<=0;
                        state<=5;
                    end
                end
                5: begin
                    if(!sent) alu_req<=1;
                    sent<=1;
                    if(alu_rdy) begin
                        P1_z<=dubbed_x;
                        sent<=0;
                        state<=6;
                    end
                end
                6: begin
                    if(!sent) inv_req<=1;
                    sent<=1;
                    if(inv_rdy) begin
                        P1_z<=inv_out;
                        sent<=0;
                        state<=7;
                    end
                end
                7: begin
                    if(!sent) mult_req<=1;
                    sent<=1;
                    if(mult_rdy) begin
                        P0_z<=mult_out;
                        sent<=0;
                        state<=8;
                    end
                end
                8: begin
                    if(!sent) mult_req<=1;
                    sent<=1;
                    if(mult_rdy) begin
                        P0_x<=mult_out;
                        sent<=0;
                        state<=9;
                    end
                end
                9: begin
                    if(!sent) mult_req<=1;
                    sent<=1;
                    if(mult_rdy) begin
                        P0_z<=mult_out;
                        sent<=0;
                        state<=10;
                    end
                end     
                10: begin
                    if(!sent) mult_req<=1;
                    sent<=1;
                    if(mult_rdy) begin
                        P0_y<=mult_out;
                        sent<=0;
                        did_it<=0;
                        state<=0;
                        rdy<=1;
                    end
                end        
            endcase
            
            if(spi_clk | !spi_clk) prev_spi_clk<=spi_clk;

            if(spi_clk & spi_clk!=prev_spi_clk) begin
                if(cs & !start_sending) begin
                    count_spi<=count_spi+1;
                    if(count_spi<WIDTH) begin
                        P1_x<=P1_x>>1;
                        P1_x[WIDTH-1]<=spi_pad_MOSI;
                    end else if(count_spi<2*WIDTH) begin
                        P1_y<=P1_y>>1;
                        P1_y[WIDTH-1]<=spi_pad_MOSI;
                    end else if(count_spi<3*WIDTH) begin
                        a<=a>>1;
                        a[WIDTH-1]<=spi_pad_MOSI;
                    end else if(count_spi<4*WIDTH) begin
                        mod<=mod>>1;
                        mod[WIDTH-1]<=spi_pad_MOSI;
                    end else if(count_spi<5*WIDTH) begin
                        k<=k>>1;
                        k[WIDTH-1]<=spi_pad_MOSI;
                    end else if(count_spi==5*WIDTH) begin
                        req<=1;
                    end else begin
                        req<=0;
                    end
                end else begin
                    count_spi<=0;
                    req<=0;
                end
                if(rdy) begin
                    count_spi<=count_spi+1;
                    if(!start_sending) begin
                        count_spi<=0;
                        start_sending<=1;
                    end else begin
                        if(count_spi<WIDTH) P0_x<={P0_x[0],P0_x[WIDTH-1:1]};
                        else if(count_spi<(2*WIDTH)) P0_y<={P0_y[0],P0_y[WIDTH-1:1]};
                        else rdy<=0;
                    end

                end
            end
        end
    end

point_alu #(.WIDTH(WIDTH)) alu (
    .clk(clk), .rst(rst), .req(alu_req), .first(first),
    .P1_x(dub_x), .P1_y(dub_y), .P1_z(dub_z),
    .P2_x(sum_x), .P2_y(sum_y), .P2_z(sum_z),
    .a(a), .mod(mod), .mult(alu_mult_only),
    .rdy(alu_rdy), .Psum_x(summed_x), .Psum_y(summed_y), .Psum_z(summed_z),
    .Pd_x(dubbed_x), .Pd_y(dubbed_y), .Pd_z(dubbed_z)
);

inverse #(.WIDTH(WIDTH)) inversion (
    .clk(clk), .rst(rst), .req(inv_req),
    .inv_in(inv_in), .mod(mod), .inv_out(inv_out), .rdy(inv_rdy)
); 

mod_mult #(.WIDTH(WIDTH)) mult (
    .clk(clk), .rst(rst), .req(mult_req),
    .mult_a(mult_a), .mult_b(mult_b), .mod(mod),
    .mult_out(mult_out), .rdy(mult_rdy)
);

endmodule

module mod_mult #(
    parameter WIDTH = 256
) (
    input  logic             clk,
    input  logic             rst,
    input  logic             req,
    input  logic [WIDTH-1:0] mult_a,
    input  logic [WIDTH-1:0] mult_b,
    input  logic [WIDTH-1:0] mod,
    
    output logic [WIDTH-1:0] mult_out,
    output logic             rdy
);

    typedef enum logic [1:0] {
        IDLE, 
        CALC, 
        DONE_ST
    } state_t;
    
    state_t state;

    logic [WIDTH-1:0]       a_reg, b_reg, m_reg;
    logic [$clog2(WIDTH)-1:0] count;
    logic [WIDTH+1:0]       p_reg; 
    logic [WIDTH+1:0]       next_p, trial_val;

    always_comb begin
        trial_val = (p_reg << 1) + (a_reg[WIDTH-1] ? {2'b0,b_reg} : 0);

        if (trial_val >= {1'b0,m_reg, 1'b0}) begin
            next_p = trial_val - {m_reg, 1'b0};
        end else if (trial_val >= {2'b0,m_reg}) begin
            next_p = trial_val - {2'b0,m_reg};
        end else begin
            next_p = trial_val;
        end
    end


    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state  <= IDLE;
            p_reg  <= '0;
            a_reg  <= '0;
            b_reg  <= '0;
            m_reg  <= '0;
            count  <= '0;
            rdy   <= 1'b0;
            mult_out <= '0;
        end else begin
            case (state)
                IDLE: begin
                    rdy <= 1'b0;
                    if (req) begin
                        a_reg <= mult_a;
                        b_reg <= mult_b;
                        m_reg <= mod;
                        p_reg <= '0;
                        count <= 8'(WIDTH - 1);
                        state <= CALC;
                    end
                end

                CALC: begin
                    p_reg <= next_p;
                    a_reg <= {a_reg[WIDTH-2:0], 1'b0};
                    
                    if (count == 0) begin
                        state <= DONE_ST;
                    end else begin
                        count <= count - 1;
                    end
                end

                DONE_ST: begin
                    mult_out <= p_reg[WIDTH-1:0];
                    rdy   <= 1'b1;
                    state  <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule

module inverse #(
    parameter WIDTH = 256
)(
    input  logic             clk,
    input  logic             rst,
    input  logic             req,
    input  logic [WIDTH-1:0] inv_in,
    input  logic [WIDTH-1:0] mod,
    output logic [WIDTH-1:0] inv_out,
    output logic             rdy
);

    // -----------------------------------------------------------------------
    // Constant-time bound: ceil((49*WIDTH + 80) / 17)
    // For WIDTH=512 this is 1481 iterations – always the same count.
    // -----------------------------------------------------------------------
    localparam ITER_MAX = (49 * WIDTH + 80 + 16) / 17;   // ceiling division
    localparam ITER_W   = $clog2(ITER_MAX + 1);

    localparam DELTA_W  = $clog2(WIDTH) + 3;

    typedef enum logic [1:0] {
        IDLE = 2'b00,
        CALC = 2'b01,
        DONE = 2'b10
    } state_t;
    state_t state, next_state;

    // State registers
    logic signed [WIDTH+1:0]   f_reg,  next_f;
    logic signed [WIDTH+1:0]   g_reg,  next_g;
    logic signed [DELTA_W-1:0] delta_reg, next_delta;
    logic        [WIDTH:0]     d_reg,  next_d;
    logic        [WIDTH:0]     e_reg,  next_e;
    logic        [WIDTH-1:0]   mod_reg;

    // Iteration counter (the only thing that drives FSM transitions)
    logic [ITER_W-1:0] iter_cnt, next_iter_cnt;

    // Combinational nodes
    logic                      c, swap;
    logic signed [DELTA_W-1:0] delta_prime;
    logic signed [WIDTH+1:0]   f_prime, g_prime;
    logic        [WIDTH:0]     d_prime, e_prime;
    logic        [WIDTH:0]     E_val;

    assign rdy = (state == DONE);

    // -----------------------------------------------------------------------
    // Sequential logic
    // -----------------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            f_reg     <= '0;
            g_reg     <= '0;
            delta_reg <= '0;
            d_reg     <= '0;
            e_reg     <= '0;
            mod_reg   <= '0;
            inv_out   <= '0;
            iter_cnt  <= '0;
        end else begin
            state     <= next_state;
            f_reg     <= next_f;
            g_reg     <= next_g;
            delta_reg <= next_delta;
            d_reg     <= next_d;
            e_reg     <= next_e;
            iter_cnt  <= next_iter_cnt;

            if (req && state == IDLE)
                mod_reg <= mod;

            // ---------------------------------------------------------------
            // Result capture: fire on the last CALC→DONE transition.
            // Use next_f / next_d because the final divstep IS applied this
            // cycle (unlike the original early-exit path where g==0 meant no
            // divstep was applied and f_reg/d_reg were already final).
            // ---------------------------------------------------------------
            if (next_state == DONE && state == CALC) begin
                if (next_f == '1)   // f == -1  →  negate inverse mod M
                    inv_out <= (next_d[WIDTH-1:0] == '0) ? '0
                                                         : (mod_reg - next_d[WIDTH-1:0]);
                else
                    inv_out <= next_d[WIDTH-1:0];
            end
        end
    end

    // -----------------------------------------------------------------------
    // Combinational divstep logic  (unchanged from original)
    // -----------------------------------------------------------------------
    always_comb begin
        // Defaults
        next_state    = state;
        next_f        = f_reg;
        next_g        = g_reg;
        next_delta    = delta_reg;
        next_d        = d_reg;
        next_e        = e_reg;
        next_iter_cnt = iter_cnt;

        // 1. Condition evaluation
        c    = g_reg[0];
        swap = c & (delta_reg > 0);

        // 2. Conditional swap (pre-calculation mux)
        if (swap) begin
            delta_prime = -delta_reg;
            f_prime     = g_reg;
            g_prime     = -f_reg;
            d_prime     = e_reg;
            e_prime     = (d_reg == '0) ? '0 : ({1'b0, mod_reg} - d_reg);
        end else begin
            delta_prime = delta_reg;
            f_prime     = f_reg;
            g_prime     = g_reg;
            d_prime     = d_reg;
            e_prime     = e_reg;
        end

        // 3. Modular addition then divide-by-2
        if (c) begin
            E_val = e_prime + d_prime;
            if (E_val >= {1'b0, mod_reg})
                E_val = E_val - {1'b0, mod_reg};
        end else begin
            E_val = e_prime;
        end

        // 4. FSM
        case (state)

            IDLE: begin
                if (req) begin
                    next_state    = CALC;
                    next_f        = $signed({2'b00, mod});
                    next_g        = $signed({2'b00, inv_in});
                    next_delta    = 1;
                    next_d        = '0;
                    next_e        = {{WIDTH{1'b0}}, 1'b1};  // 1
                    next_iter_cnt = '0;
                end
            end

            CALC: begin
                // ----------------------------------------------------------
                // Always apply one divstep – NO early exit.
                // The FSM runs for exactly ITER_MAX cycles every invocation.
                // ----------------------------------------------------------
                next_delta = delta_prime + 1;
                next_f     = f_prime;
                next_d     = d_prime;

                next_g = c ? ($signed(g_prime + f_prime) >>> 1)
                           : ($signed(g_prime)           >>> 1);

                next_e = E_val[0] ? ((E_val + {1'b0, mod_reg}) >> 1)
                                  : (E_val                      >> 1);

                // Advance counter; transition only when all steps are done
                next_iter_cnt = iter_cnt + 1'b1;

                if (iter_cnt == ITER_W'(ITER_MAX - 1))
                    next_state = DONE;
            end

            DONE: begin
                // Hold for one cycle so rdy is visible, then return to IDLE
                next_state = IDLE;
            end

            default: next_state = IDLE;

        endcase
    end

endmodule

module modadd #( //module for addition, ctrl=1 subtraction, ctrl=0 addition
    parameter WIDTH = 256
)(
    input logic ctrl,
    input logic [WIDTH-1:0] a,
    input logic [WIDTH-1:0] b,
    input logic [WIDTH-1:0] mod,
    output logic [WIDTH-1:0] result
);
    logic [WIDTH:0] val_1;
    logic [WIDTH-1:0] val_2;

    always_comb begin
        if(ctrl) begin
            val_1 = {1'b0,a} - {1'b0,b};
            val_2 = val_1[WIDTH-1:0] + mod;
            result = (a>=b) ? val_1[WIDTH-1:0] : val_2[WIDTH-1:0];
        end else begin
            val_1 = {1'b0,a} + {1'b0,b};
            val_2 = val_1[WIDTH-1:0] - mod;
            result = (val_1>={1'b0,mod}) ? val_2[WIDTH-1:0] : val_1[WIDTH-1:0];
        end
    end

endmodule

module modmul#( // radix 4 montgomery multiplication, requires and b be in a*R form alreadt
    parameter WIDTH = 256
)(
    input  logic              clk,
    input  logic              rst,
    input  logic              req,
    input  logic [WIDTH-1:0]  a,
    input  logic [WIDTH-1:0]  b,
    input  logic [WIDTH-1:0]  mod,
    output logic [WIDTH-1:0]  result,
    output logic              rdy
);

    typedef enum logic [1:0] {
        IDLE     = 2'b00,
        PRECOMP  = 2'b01, // Calculate 3b and 3mod
        COMPUTE  = 2'b10, // Main loop (2 bits per cycle)
        FINISH   = 2'b11  // Final reduction
    } state_t;

    state_t state;

    logic [WIDTH+2:0] S;
    logic [WIDTH-1:0] a_reg;
    logic [WIDTH+1:0] b3;
    logic [WIDTH+1:0] mod3; 
    logic [1:0] mod_inv;
    logic [$clog2(WIDTH/2):0] count;

    logic [1:0] a_i;
    logic [1:0] q_i;
    logic [WIDTH+1:0] term_b;
    logic [WIDTH+1:0] term_mod;

    assign a_i = a_reg[1:0];

    always_comb begin
        case (a_i)
            2'b01:   term_b = {2'b0, b};
            2'b10:   term_b = {2'b0, b}<<1;
            2'b11:   term_b = b3;
            default: term_b = '0;
        endcase
    end

    assign q_i = ( (S[1:0] + term_b[1:0]) * mod_inv ) & 2'b11;

    always_comb begin
        case (q_i)
            2'b01:   term_mod = {2'b0, mod};
            2'b10:   term_mod = {2'b0, mod}<<1;
            2'b11:   term_mod = mod3;
            default: term_mod = '0;
        endcase
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            rdy <= 1'b0;
            result <= '0;
            S <= '0;
        end else begin
            case (state)
                IDLE: begin
                    rdy <= 1'b0;
                    if (req) begin
                        a_reg <= a;
                        mod_inv <= (mod[1]) ? 2'b01 : 2'b11; 
                        state <= PRECOMP;
                    end
                end

                PRECOMP: begin
                    b3 <= ({2'b0, b} << 1) + {2'b0, b};
                    mod3 <= ({2'b0, mod} << 1) + {2'b0, mod};
                    S <= '0;
                    count <= 8'(WIDTH / 2);
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    if (count > 0) begin
                        S <= (S + term_b + term_mod) >> 2;
                        a_reg <= a_reg >> 2;
                        count <= count - 1;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    if (S >= {3'b0,mod}) begin
                        result <= WIDTH'(S - {3'b0,mod});
                    end else begin
                        result <= S[WIDTH-1:0];
                    end
                    rdy <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

module point_alu #(
    parameter WIDTH = 256
)(
    input  logic              clk,
    input  logic              rst,
    input  logic              req,
    input  logic              first, 
    input  logic              mult,
    input  logic [WIDTH-1:0]  P1_x, P1_y, P1_z,
    input  logic [WIDTH-1:0]  P2_x, P2_y, P2_z,
    input  logic [WIDTH-1:0] a, mod,
    output logic              rdy,
    output logic [WIDTH-1:0]  Psum_x, Psum_y, Psum_z,
    output logic [WIDTH-1:0]  Pd_x, Pd_y, Pd_z
);

    logic [WIDTH-1:0] mult_a [2], mult_b [2], mult_out [2];
    logic             mult_req [2], mult_rdy [2];

    logic [WIDTH-1:0] add_a [2], add_b [2], add_out [2];
    logic             add_ctrl [2];

    logic [WIDTH-1:0] mem [0:10];
    logic [1:0] done_flags;
    logic [1:0] sent;

    logic [4:0] state;

    always_comb begin 
        Pd_x=0;
        Pd_y=0;
        Pd_z=0;
        Psum_x=0;
        Psum_y=0;
        Psum_z=0;
           
        
        if(rdy) begin
            Pd_x = mem[2]; Pd_y = mem[3]; Pd_z = mem[4];
            if(!first)begin
                Psum_x = mem[10]; Psum_y = mem[1]; Psum_z = mem[5];
            end else begin
                Psum_x = P1_x;  Psum_y = P1_y; Psum_z = P1_z;
            end
        end

        mult_a[0] = 0;   mult_b[0] = 0;   mult_req[0] = 0;
        mult_a[1] = 0;   mult_b[1] = 0;   mult_req[1] = 0;
        add_a[0]  = 0; add_b[0] = 0; add_ctrl[0] = 0;
        add_a[1]  = 0; add_b[1] = 0; add_ctrl[1] = 0;

        case(state)
            0: begin
                if(mult) begin
                    mult_a[0] = P2_x; mult_b[0] = 1; mult_req[0] = !sent[0];
                end
            end
            1: begin
                mult_a[0] = P1_z;   mult_b[0] = P1_z;   mult_req[0] = !sent[0];
                mult_a[1] = P2_z;   mult_b[1] = P2_z;   mult_req[1] = !sent[1];
            end
            2: begin
                mult_a[0] = mem[0];   mult_b[0] = P1_z;   mult_req[0] = !sent[0];
                mult_a[1] = mem[1];   mult_b[1] = P2_z;   mult_req[1] = !sent[1];
            end
            3: begin
                mult_a[0] = P1_y;   mult_b[0] = mem[3];   mult_req[0] = !sent[0];
                mult_a[1] = P2_y;   mult_b[1] = mem[2];   mult_req[1] = !sent[1];
            end
            4: begin
                mult_a[0] = P1_x;   mult_b[0] = mem[1];   mult_req[0] = !sent[0];
                mult_a[1] = P2_x;   mult_b[1] = mem[0];   mult_req[1] = !sent[1];
            end
            5: begin
                mult_a[0] = P1_x;   mult_b[0] = P1_x;   mult_req[0] = !sent[0];
                mult_a[1] = P1_y;   mult_b[1] = P1_z;   mult_req[1] = !sent[1];
                add_a[0]  = mem[1]; add_b[0] = mem[4]; add_ctrl[0] = 1;
                add_a[1]  = mem[2]; add_b[1] = mem[3]; add_ctrl[1] = 1;
            end
            6: begin
                mult_a[0] = mem[0];   mult_b[0] = mem[0];   mult_req[0] = !sent[0];
                mult_a[1] = mem[5];   mult_b[1] = mem[5];   mult_req[1] = !sent[1];
                add_a[0]  = mem[3]; add_b[0] = mem[3]; add_ctrl[0] = 0;
                add_a[1]  = mem[4]; add_b[1] = mem[4]; add_ctrl[1] = 0;
            end
            7: begin
                mult_a[0] = mem[1];   mult_b[0] = mem[7];   mult_req[0] = !sent[0];
                mult_a[1] = mem[5];   mult_b[1] = mem[7];   mult_req[1] = !sent[1];
                add_a[0]  = mem[3]; add_b[0] = mem[8]; add_ctrl[0] = 0;
            end
            8: begin
                mult_a[0] = mem[6];   mult_b[0] = mem[6];   mult_req[0] = !sent[0];
            end
            9: begin
                mult_a[0] = a;   mult_b[0] = mem[0];   mult_req[0] = !sent[0];
                mult_a[1] = P1_y;   mult_b[1] = P1_y;   mult_req[1] = !sent[1];
                add_a[0]  = mem[9]; add_b[0] = mem[7]; add_ctrl[0] = 0;
                add_a[1]  = mem[1]; add_b[1] = mem[1]; add_ctrl[1] = 0;
            end
            10: begin
                mult_a[0] = P1_x;   mult_b[0] = mem[8];   mult_req[0] = !sent[0];
                mult_a[1] = mem[2];   mult_b[1] = mem[7];   mult_req[1] = !sent[1];
                add_a[0]  = mem[9]; add_b[0] = mem[10]; add_ctrl[0] = 1;
                add_a[1]  = mem[0]; add_b[1] = mem[3]; add_ctrl[1] = 0;
            end
            11: begin
                mult_a[0] = mem[8];   mult_b[0] = mem[8];   mult_req[0] = !sent[0];
                mult_a[1] = P1_z;   mult_b[1] = P2_z;   mult_req[1] = !sent[1];
                add_a[0]  = mem[1]; add_b[0] = mem[10]; add_ctrl[0] = 1;
                add_a[1]  = mem[9]; add_b[1] = mem[9]; add_ctrl[1] = 0;
            end
            12: begin
                mult_a[0] = mem[1];   mult_b[0] = mem[6];   mult_req[0] = !sent[0];
                mult_a[1] = mem[5];   mult_b[1] = mem[7];   mult_req[1] = !sent[1];
                add_a[0]  = mem[3]; add_b[0] = mem[3]; add_ctrl[0] = 0;
                add_a[1]  = mem[9]; add_b[1] = mem[9]; add_ctrl[1] = 0;
            end
            13: begin
                mult_a[0] = mem[0];   mult_b[0] = mem[0];   mult_req[0] = !sent[0];
                add_a[0]  = mem[1]; add_b[0] = mem[2]; add_ctrl[0] = 1;
                add_a[1]  = mem[9]; add_b[1] = mem[9]; add_ctrl[1] = 0;
            end
            14: begin
                add_a[0]  = mem[2]; add_b[0] = mem[6]; add_ctrl[0] = 1;
                add_a[1]  = mem[3]; add_b[1] = mem[3]; add_ctrl[1] = 0;
            end
            15: begin
                add_a[0]  = mem[9]; add_b[0] = mem[2]; add_ctrl[0] = 1;
                add_a[1]  = mem[3]; add_b[1] = mem[3]; add_ctrl[1] = 0;
            end
            16: begin
                mult_a[0] = mem[0];   mult_b[0] = mem[6];   mult_req[0] = !sent[0];
            end
            17: begin
                add_a[0]  = mem[6]; add_b[0] = mem[3]; add_ctrl[0] = 1;
            end
            19 : begin
                mult_a[0] = P2_x; mult_b[0] = 1; mult_req[0] = !sent[0];
            end
            default: ;
        endcase
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= 0;
            rdy <= 0;
            done_flags <= 2'b00;
            sent<=0;
        end else begin
            case (state)
                0: begin
                    sent<=0;
                    rdy <= 0;
                    if (req) begin
                        state <= 1;
                        if(mult) state<=19;
                    end
                end

                // Multiplier States (Wait for both to finish)
                1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17: begin

                    sent<=3;

                    if (mult_rdy[0]) begin done_flags[0] <= 1; end
                    if (mult_rdy[1]) begin done_flags[1] <= 1; end

                    if ((done_flags[0] || mult_rdy[0]) && (done_flags[1] || mult_rdy[1])) begin
                        done_flags <= 0;

                        case(state)
                            1:   begin mem[0] <= mult_out[0]; mem[1] <= mult_out[1];end  
                            2:   begin mem[2] <= mult_out[0]; mem[3] <= mult_out[1];end  
                            3:   begin mem[2] <= mult_out[0]; mem[3] <= mult_out[1];end  
                            4:   begin mem[1] <= mult_out[0]; mem[4] <= mult_out[1];end  
                            5:   begin mem[3] <= mult_out[0]; mem[4] <= mult_out[1]; mem[5] <= add_out[0]; mem[6] <= add_out[1];end  
                            6:   begin mem[0] <= mult_out[0]; mem[7] <= mult_out[1]; mem[8] <= add_out[0]; mem[4] <= add_out[1];end  
                            7:   begin mem[1] <= mult_out[0]; mem[7] <= mult_out[1]; mem[3] <= add_out[0];end  
                            9:   begin mem[0] <= mult_out[0]; mem[8] <= mult_out[1]; mem[9] <= add_out[0]; mem[10] <= add_out[1];end  
                            10:   begin mem[9] <= mult_out[0]; mem[2] <= mult_out[1]; mem[10] <= add_out[0]; mem[0] <= add_out[1];end  
                            11:   begin mem[3] <= mult_out[0]; mem[7] <= mult_out[1]; mem[1] <= add_out[0]; mem[9] <= add_out[1];end  
                            12:   begin mem[1] <= mult_out[0]; mem[5] <= mult_out[1]; mem[3] <= add_out[0]; mem[9] <= add_out[1];end  
                            endcase
                        sent<=0;
                        state <= state+1;
                    end
                    
                    if((state == 8) && (done_flags[0] || mult_rdy[0])) begin
                        mem[9]<=mult_out[0];
                        sent<=0;
                        state <= state+1;
                    end

                    if(state>12) begin
                        case(state)
                            14: begin
                                mem[2] <= add_out[0]; mem[3] <= add_out[1];
                                sent<=0;
                                state <= state+1;
                            end
                            15: begin
                                mem[6] <= add_out[0]; mem[3] <= add_out[1];
                                sent<=0;
                                state <= state+1;
                            end
                            17: begin
                                mem[3] <= add_out[0];
                                sent<=0;
                                state <= state+1;
                            end
                            default: ;
                        endcase
                        if(state == 13) sent<=3;

                        if((state == 13) && (done_flags[0] || mult_rdy[0])) begin
                            mem[2] <= mult_out[0]; mem[1] <= add_out[0]; mem[6] <= add_out[1];
                            sent<=0;
                            state <= state+1;
                            done_flags <= 0;
                        end

                        if(state == 16) sent<=3;

                        if((state == 16) && (done_flags[0] || mult_rdy[0])) begin
                            mem[6] <= mult_out[0];
                            sent<=0;
                            state <= state+1;
                            done_flags <= 0;
                        end
                    end
                end

                18: begin
                    rdy   <= 1;
                    state <= 0;
                end

                19: begin
                    sent[0]<=1;
                    if(mult_rdy[0]) begin
                        mem[2]<=mult_out[0];
                        rdy<=1;
                        state<=0;
                    end
                end
            endcase
        end
    end

    // --- Hardware Instantiations ---
    modmul #(.WIDTH(WIDTH)) mult0 (.clk(clk), .rst(rst), .req(mult_req[0]), .a(mult_a[0]), .b(mult_b[0]), .mod(mod), .result(mult_out[0]), .rdy(mult_rdy[0]));
    modmul #(.WIDTH(WIDTH)) mult1 (.clk(clk), .rst(rst), .req(mult_req[1]), .a(mult_a[1]), .b(mult_b[1]), .mod(mod), .result(mult_out[1]), .rdy(mult_rdy[1]));

    modadd #(.WIDTH(WIDTH)) add0  (.ctrl(add_ctrl[0]), .a(add_a[0]), .b(add_b[0]), .mod(mod), .result(add_out[0]));
    modadd #(.WIDTH(WIDTH)) add1  (.ctrl(add_ctrl[1]), .a(add_a[1]), .b(add_b[1]), .mod(mod), .result(add_out[1]));

endmodule