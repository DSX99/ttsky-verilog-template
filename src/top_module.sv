module top_module #(
    parameter WIDTH = 64
)(
    input logic cs,
    input logic spi_clk,
    input logic spi_pad_MOSI,
    input logic clk,rst,
    output logic rdy,
    output logic spi_pad_MISO
);

    logic [WIDTH-1:0] P0_x,P0_y,P0_z,P1_x,P1_y,P1_z;
    logic [WIDTH-1:0] a,mod,summed_x,summed_y,summed_z,dubbed_x,dubbed_y,dubbed_z;
    logic [$clog2(WIDTH)+5:0] count_spi;
    logic req, alu_rdy, start_sending, alu_mult_only, prev_spi_clk, first;

    always_comb begin
        spi_pad_MISO=0;
        alu_mult_only=0;
        if(rdy) begin
            if(count_spi<WIDTH)begin
                spi_pad_MISO=P0_x[0];
            end else if(count_spi<2*WIDTH) begin
                spi_pad_MISO=P0_y[0];
            end else if(count_spi<3*WIDTH) begin
                spi_pad_MISO=P0_z[0];
            end else if(count_spi<4*WIDTH) begin
                spi_pad_MISO=P1_x[0];
            end else if(count_spi<5*WIDTH) begin
                spi_pad_MISO=P1_y[0];
            end else if(count_spi<6*WIDTH) begin
                spi_pad_MISO=P1_z[0];
            end 
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if(rst)begin
            P0_x<=0; P0_y<=0; P0_z<=569; P1_x<=0; P1_y<=0; P1_z<=569;
            a<=0; mod<=0; count_spi<=0; rdy<=0; req<=0; prev_spi_clk<=0;
            start_sending<=0;

        end else begin

            if(alu_rdy) begin
                rdy<=alu_rdy;
                P0_x<=dubbed_x; 
                P0_y<=dubbed_y; 
                P0_z<=dubbed_z;
                P1_x<=summed_x; 
                P1_y<=summed_y; 
                P1_z<=summed_z;
            end

            if(spi_clk | !spi_clk) prev_spi_clk<=spi_clk;

            if(spi_clk & spi_clk!=prev_spi_clk) begin
                if(cs & !start_sending) begin
                    count_spi<=count_spi+1;
                    if(count_spi<WIDTH) begin
                        P0_x<=P0_x>>1;
                        P0_x[WIDTH-1]<=spi_pad_MOSI;
                    end else if(count_spi<2*WIDTH) begin
                        P0_y<=P0_y>>1;
                        P0_y[WIDTH-1]<=spi_pad_MOSI;
                    end else if(count_spi<3*WIDTH) begin
                        P0_z<=P0_z>>1;
                        P0_z[WIDTH-1]<=spi_pad_MOSI;
                    end else if(count_spi<4*WIDTH) begin
                        P1_x<=P1_x>>1;
                        P1_x[WIDTH-1]<=spi_pad_MOSI;
                    end else if(count_spi<5*WIDTH) begin
                        P1_y<=P1_y>>1;
                        P1_y[WIDTH-1]<=spi_pad_MOSI;
                    end else if(count_spi<6*WIDTH) begin
                        P1_z<=P1_z>>1;
                        P1_z[WIDTH-1]<=spi_pad_MOSI;
                    end else if(count_spi<7*WIDTH) begin
                        a<=a>>1;
                        a[WIDTH-1]<=spi_pad_MOSI;
                    end else if(count_spi<8*WIDTH) begin
                        mod<=mod>>1;
                        mod[WIDTH-1]<=spi_pad_MOSI;
                    end else if(count_spi==8*WIDTH) begin
                        first<=spi_pad_MOSI;
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
                        else if(count_spi<2*WIDTH) P0_y<={P0_y[0],P0_y[WIDTH-1:1]};
                        else if(count_spi<3*WIDTH) P0_z<={P0_z[0],P0_z[WIDTH-1:1]};
                        else if(count_spi<4*WIDTH) P1_x<={P1_x[0],P1_x[WIDTH-1:1]};
                        else if(count_spi<5*WIDTH) P1_y<={P1_y[0],P1_y[WIDTH-1:1]};
                        else if(count_spi<6*WIDTH) P1_z<={P1_z[0],P1_z[WIDTH-1:1]};
                        else begin 
                            rdy<=0; 
                            start_sending<=0;
                        end
                    end

                end
            end
        end
    end

point_alu #(.WIDTH(WIDTH)) alu (
    .clk(clk), .rst(rst), .req(req), .first(first),
    .P1_x(P0_x), .P1_y(P0_y), .P1_z(P0_z),
    .P2_x(P1_x), .P2_y(P1_y), .P2_z(P1_z),
    .a(a), .mod(mod), .mult(alu_mult_only),
    .rdy(alu_rdy), .Psum_x(summed_x), .Psum_y(summed_y), .Psum_z(summed_z),
    .Pd_x(dubbed_x), .Pd_y(dubbed_y), .Pd_z(dubbed_z)
);

endmodule

module modadd #( //module for addition, ctrl=1 subtraction, ctrl=0 addition
    parameter WIDTH = 64
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

module modmul#( // radix 4 montgomery multiplication, requires a and b be in a*R form alreadt
    parameter WIDTH = 64
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
                    count <= 6'(WIDTH / 2);
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
    parameter WIDTH = 64
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
        
        Psum_x=0;Psum_y=0;Psum_z=0;Pd_x=0;Pd_y=0;Pd_z=0;
        mult_req[0] = 0; mult_a[0] = '0; mult_b[0] = '0;
        mult_req[1] = 0; mult_a[1] = '0; mult_b[1] = '0;

        mult_a[0] = 0;   mult_b[0] = 0;   mult_req[0] = 0;
        mult_a[1] = 0;   mult_b[1] = 0;   mult_req[1] = 0;
        add_a[0]  = 0; add_b[0] = 0;
        add_a[1]  = 0; add_b[1] = 0;
        add_ctrl[0]=0;add_ctrl[1]=0;

        if(rdy) begin
            Pd_x = mem[2]; Pd_y = mem[3]; Pd_z = mem[4];
            if(!first)begin
                Psum_x = mem[10]; Psum_y = mem[1]; Psum_z = mem[5];
            end else begin
                Psum_x = P1_x;  Psum_y = P1_y; Psum_z = P1_z;
            end
        end

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
                    rdy <= 0;
                    sent<=0;
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
