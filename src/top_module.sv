module top_module #(
    parameter WIDTH = 256
)(
    input logic cs,
    input logic spi_clk,
    input logic spi_pad_MOSI,
    input logic clk,rst,
    input logic [1:0] do_operation,
    output logic rdy,
    output logic spi_pad_MISO
);

    logic [WIDTH-1:0] mem [9:0];
    logic [WIDTH+1:0] extmem[1:0];
    logic [$clog2(WIDTH)+4:0] count_spi;
    logic start_sending, prev_spi_clk, start_receiving;
    logic [1:0] mem_set;
    logic [4:0] state, return_state;
    logic [3:0] roll, spi_slot;
    logic req, save_a, save_b, sent;

    always_comb begin 
        if(spi_slot<=9) spi_pad_MISO=mem[spi_slot][0];
        else spi_pad_MISO=0;
    end

    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            mem[0]<=0;mem[1]<=0;mem[2]<=0;mem[3]<=0;mem[4]<=0;mem[5]<=0;mem[6]<=0;mem[7]<=0;mem[8]<=0;mem[9]<=0;extmem[1]<=0;extmem[0]<=0;
            count_spi<=0; start_sending<=0; prev_spi_clk<=0; rdy<=0; spi_slot<=0; start_receiving<=0;
            mem_set<=0; return_state<=0; req<=0; roll<=0;
            save_a<=0; save_b<=0; state<=0; sent<=0;
            add_ctrl<=0;
            mult_req<=0;
            prev_req<=0;
            state_mul    <= 0;
            count    <= 0;
            mult_rdy      <= 0;
            mult_mem_a<=0;
            mult_mem_b<=0;
        end else begin
            if(state!=1 & state!=0 & state<20) begin
                case(mem_set)
                    0: begin
                        save_a<=1;
                        save_b<=0;
                        state<=1;
                        mem_set<=1;
                    end
                    1: begin
                        save_a<=0;
                        save_b<=1;
                        state<=1;
                        mem_set<=2;
                    end
                    2: begin
                        save_a<=0;
                        save_b<=0;
                        state<=1;
                        mem_set<=3;
                    end
                    3: begin
                        return_state<=state+1;
                    end
                endcase
            end

            case(state)
                0:begin
                    if(req) begin
                        rdy<=0;
                        case(do_operation)
                            0:begin
                                state<=2; // normal alu
                            end
                            1:begin
                                state<=21; //mult
                            end
                            2:begin
                                state<=22; //add
                            end
                            3:begin
                                state<=23; //sub
                            end
                        endcase
                    end
                end
                1:begin //state to rotate mems
                    if(roll==0) begin
                        if(save_a) extmem[0]<={2'b0,mem[0]};
                        if(save_b) extmem[1]<={2'b0,mem[0]};
                        state<=return_state;
                    end else begin
                        roll<=roll-1;
                        mem[0]<=mem[1];
                        mem[1]<=mem[2];
                        mem[2]<=mem[3];
                        mem[3]<=mem[4];
                        mem[4]<=mem[5];
                        mem[5]<=mem[6];
                        mem[6]<=mem[7];
                        mem[7]<=mem[8];
                        mem[8]<=mem[0];
                    end
                end
                2:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=1;
                            mem_set<=1;
                        end
                        1: begin
                            roll<=1;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=2;
                            mem_set<=3;
                        end
                        3: begin
                            if(~sent) begin 
                                mult_req<=1;
                                sent<=1;
                            end else begin
                                mult_req<=0;
                            end
                            if(mult_rdy) begin
                                mem[0]<=WIDTH'(extmem[0]);
                                roll<=5;
                                state<=1;
                                mem_set<=0;
                                sent<=0;
                            end
                        end
                    endcase
                end
                3:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=4;
                            mem_set<=1;
                            add_ctrl<=0;
                        end
                        1: begin
                            roll<=0;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=0;
                            mem_set<=3;
                        end
                        3: begin
                            mem[0]<=add_out;
                            roll<=5;
                            state<=1;
                            mem_set<=0;
                        end
                    endcase
                end
                4:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=3;
                            mem_set<=1;
                            add_ctrl<=0;
                        end
                        1: begin
                            roll<=1;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=0;
                            mem_set<=3;
                        end
                        3: begin
                            mem[0]<=add_out;
                            roll<=5;
                            state<=1;
                            mem_set<=0;
                        end
                    endcase
                end
                5:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=0;
                            mem_set<=1;
                            add_ctrl<=1;
                        end
                        1: begin
                            roll<=1;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=4;
                            mem_set<=3;
                        end
                        3: begin
                            mem[0]<=add_out;
                            roll<=4;
                            state<=1;
                            mem_set<=0;
                        end
                    endcase
                end
                6:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=4;
                            mem_set<=1;
                        end
                        1: begin
                            roll<=1;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=1;
                            mem_set<=3;
                        end
                        3: begin
                            if(~sent) begin 
                                mult_req<=1;
                                sent<=1;
                            end else begin
                                mult_req<=0;
                            end
                            if(mult_rdy) begin
                                mem[0]<=WIDTH'(extmem[0]);
                                roll<=3;
                                state<=1;
                                mem_set<=0;
                                sent<=0;
                            end
                        end
                    endcase
                end
                7:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=5;
                            mem_set<=1;
                        end
                        1: begin
                            roll<=0;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=2;
                            mem_set<=3;
                        end
                        3: begin
                            if(~sent) begin 
                                mult_req<=1;
                                sent<=1;
                            end else begin
                                mult_req<=0;
                            end
                            if(mult_rdy) begin
                                mem[0]<=WIDTH'(extmem[0]);
                                roll<=2;
                                state<=1;
                                mem_set<=0;
                                sent<=0;
                            end
                        end
                    endcase
                end
                8:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=1;
                            mem_set<=1;
                        end
                        1: begin
                            roll<=6;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=1;
                            mem_set<=3;
                        end
                        3: begin
                            if(~sent) begin 
                                mult_req<=1;
                                sent<=1;
                            end else begin
                                mult_req<=0;
                            end
                            if(mult_rdy) begin
                                mem[0]<=WIDTH'(extmem[0]);
                                roll<=1;
                                state<=1;
                                mem_set<=0;
                                sent<=0;
                            end
                        end
                    endcase
                end
                9:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=4;
                            mem_set<=1;
                        end
                        1: begin
                            roll<=0;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=5;
                            mem_set<=3;
                        end
                        3: begin
                            if(~sent) begin 
                                mult_req<=1;
                                sent<=1;
                            end else begin
                                mult_req<=0;
                            end
                            if(mult_rdy) begin
                                mem[0]<=WIDTH'(extmem[0]);
                                roll<=0;
                                state<=1;
                                mem_set<=0;
                                sent<=0;
                            end
                        end
                    endcase
                end
                10:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=2;
                            mem_set<=1;
                        end
                        1: begin
                            roll<=4;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=4;
                            mem_set<=3;
                        end
                        3: begin
                            if(~sent) begin 
                                mult_req<=1;
                                sent<=1;
                            end else begin
                                mult_req<=0;
                            end
                            if(mult_rdy) begin
                                mem[0]<=WIDTH'(extmem[0]);
                                roll<=8;
                                state<=1;
                                mem_set<=0;
                                sent<=0;
                            end
                        end
                    endcase
                end
                11:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=3;
                            mem_set<=1;
                        end
                        1: begin
                            roll<=3;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=5;
                            mem_set<=3;
                        end
                        3: begin
                            if(~sent) begin 
                                mult_req<=1;
                                sent<=1;
                            end else begin
                                mult_req<=0;
                            end
                            if(mult_rdy) begin
                                mem[0]<=WIDTH'(extmem[0]);
                                roll<=7;
                                state<=1;
                                mem_set<=0;
                                sent<=0;
                            end
                        end
                    endcase
                end
                12:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=2;
                            mem_set<=1;
                        end
                        1: begin
                            roll<=5;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=4;
                            mem_set<=3;
                        end
                        3: begin
                            if(~sent) begin 
                                mult_req<=1;
                                sent<=1;
                            end else begin
                                mult_req<=0;
                            end
                            if(mult_rdy) begin
                                mem[0]<=WIDTH'(extmem[0]);
                                roll<=7;
                                state<=1;
                                mem_set<=0;
                                sent<=0;
                            end
                        end
                    endcase
                end
                13:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=0;
                            mem_set<=1;
                            add_ctrl<=0;
                        end
                        1: begin
                            roll<=1;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=2;
                            mem_set<=3;
                        end
                        3: begin
                            mem[0]<=add_out;
                            roll<=6;
                            state<=1;
                            mem_set<=0;
                        end
                    endcase
                end
                14:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=1;
                            mem_set<=1;
                            add_ctrl<=0;
                        end
                        1: begin
                            roll<=2;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=2;
                            mem_set<=3;
                        end
                        3: begin
                            mem[0]<=add_out;
                            roll<=4;
                            state<=1;
                            mem_set<=0;
                        end
                    endcase
                end
                15:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=8;
                            mem_set<=1;
                            add_ctrl<=1;
                        end
                        1: begin
                            roll<=4;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=4;
                            mem_set<=3;
                        end
                        3: begin
                            mem[0]<=add_out;
                            roll<=2;
                            state<=1;
                            mem_set<=0;
                        end
                    endcase
                end
                16:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=0;
                            mem_set<=1;
                            add_ctrl<=1;
                        end
                        1: begin
                            roll<=5;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=1;
                            mem_set<=3;
                        end
                        3: begin
                            if(~sent) begin 
                                mult_req<=1;
                                sent<=1;
                            end else begin
                                mult_req<=0;
                            end
                            if(mult_rdy) begin
                                mem[0]<=WIDTH'(extmem[0]);
                                roll<=3;
                                state<=1;
                                mem_set<=0;
                                sent<=0;
                            end
                        end
                    endcase
                end
                17:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=8;
                            mem_set<=1;
                            add_ctrl<=1;
                        end
                        1: begin
                            roll<=0;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=5;
                            mem_set<=3;
                        end
                        3: begin
                            if(~sent) begin 
                                mult_req<=1;
                                sent<=1;
                            end else begin
                                mult_req<=0;
                            end
                            if(mult_rdy) begin
                                mem[0]<=WIDTH'(extmem[0]);
                                roll<=5;
                                state<=1;
                                mem_set<=0;
                                sent<=0;
                            end
                        end
                    endcase
                end
                18:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=2;
                            mem_set<=1;
                            add_ctrl<=0;
                        end
                        1: begin
                            roll<=2;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=1;
                            mem_set<=3;
                        end
                        3: begin
                            mem[0]<=add_out;
                            roll<=4;
                            state<=1;
                            mem_set<=0;
                        end
                    endcase
                end
                19:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=0;
                            mem_set<=1;
                            add_ctrl<=1;
                        end
                        1: begin
                            roll<=2;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=2;
                            mem_set<=3;
                        end
                        3: begin
                            if(~sent) begin 
                                mult_req<=1;
                                sent<=1;
                            end else begin
                                mult_req<=0;
                            end
                            if(mult_rdy) begin
                                mem[0]<=WIDTH'(extmem[0]);
                                roll<=5;
                                state<=1;
                                mem_set<=0;
                                sent<=0;
                            end
                        end
                    endcase
                end
                20:begin
                    rdy<=1;
                    state<=0;
                end
                21:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=0;
                            mem_set<=1;
                            add_ctrl<=1;
                            save_a<=1;
                            save_b<=0;
                            state<=1;
                            mem_set<=1;
                        end
                        1: begin
                            roll<=1;
                            mem_set<=2;
                            save_a<=0;
                            save_b<=1;
                            state<=1;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=1;
                            mem_set<=3;
                            save_a<=0;
                            save_b<=0;
                            state<=1;
                            mem_set<=3;
                        end
                        3: begin
                            if(~sent) begin 
                                mult_req<=1;
                                sent<=1;
                            end else begin
                                mult_req<=0;
                            end
                            if(mult_rdy) begin
                                return_state<=0;
                                mem[0]<=WIDTH'(extmem[0]);
                                roll<=7;
                                state<=1;
                                mem_set<=0;
                                sent<=0;
                                rdy<=1;
                            end
                        end
                    endcase
                end
                22:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=0;
                            mem_set<=1;
                            add_ctrl<=0;
                            save_a<=1;
                            save_b<=0;
                            state<=1;
                            mem_set<=1;
                        end
                        1: begin
                            roll<=1;
                            mem_set<=2;
                            save_a<=0;
                            save_b<=1;
                            state<=1;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=1;
                            mem_set<=3;
                            save_a<=0;
                            save_b<=0;
                            state<=1;
                            mem_set<=3;
                        end
                        3: begin
                            return_state<=0;
                            mem[0]<=add_out;
                            roll<=7;
                            state<=1;
                            mem_set<=0;
                            rdy<=1;
                        end
                    endcase
                end
                23:begin
                    case(mem_set)
                        0: begin
                            return_state<=state;
                            roll<=0;
                            mem_set<=1;
                            add_ctrl<=1;
                            save_a<=1;
                            save_b<=0;
                            state<=1;
                            mem_set<=1;
                        end
                        1: begin
                            roll<=1;
                            mem_set<=2;
                            save_a<=0;
                            save_b<=1;
                            state<=1;
                            mem_set<=2;
                        end
                        2: begin
                            roll<=1;
                            mem_set<=3;
                            save_a<=0;
                            save_b<=0;
                            state<=1;
                            mem_set<=3;
                        end
                        3: begin
                            return_state<=0;
                            mem[0]<=add_out;
                            roll<=7;
                            state<=1;
                            mem_set<=0;
                            rdy<=1;
                        end
                    endcase
                end
            endcase

            if(!cs) begin
                start_receiving<=0;
                req<=0;
            end
            if(spi_clk | !spi_clk) prev_spi_clk<=spi_clk;

            if(spi_clk & spi_clk!=prev_spi_clk) begin
                if(cs & !start_sending) begin
                    start_receiving<=1;
                    count_spi<=count_spi+1;
                    if(count_spi==WIDTH-1) begin
                        count_spi<=0;
                        spi_slot<=spi_slot+1;
                    end
                    mem[spi_slot]<=mem[spi_slot]>>1;
                    mem[spi_slot][WIDTH-1]<=spi_pad_MOSI;

                    if(spi_slot==10)begin
                        if(count_spi==0) req<=1;
                        else req<=0;
                    end
                end else req<=0;
                if(!cs & !start_sending) begin
                    count_spi<=0;
                    spi_slot<=0;
                end
                if(rdy & !start_receiving) begin
                    count_spi<=count_spi+1;
                    if(!start_sending) begin
                        spi_slot<=0;
                        count_spi<=0;
                        start_sending<=1;
                    end else begin
                        if(count_spi==WIDTH-1) begin
                            count_spi<=0;
                            spi_slot<=spi_slot+1;
                        end
                        
                        mem[spi_slot]<={mem[spi_slot][0],mem[spi_slot][WIDTH-1:1]};

                        if(spi_slot==9)begin
                            rdy<=0;
                        end
                    end
                end
            end
            case (state_mul)
                0: begin
                    prev_req<=mult_req;
                    mult_rdy<=0;
                    if (mult_req & ~prev_req) begin
                        mult_mem_a<=WIDTH'(extmem[0]);
                        mult_mem_b<=WIDTH'(extmem[1]);
                        extmem[0]<=0;
                        count <= 0;
                        state_mul <= 1;
                        add_ctrl <= 0;
                    end
                end
                1: begin
                    extmem[1] <= extmem[0];
                    state_mul<=2;
                end
                2: begin
                    extmem[0] <= {2'b0,add_out};
                    extmem[1] <= mult_mem_b[WIDTH-1] ? {2'b0,mult_mem_a} : 0;
                    mult_mem_b<=mult_mem_b<<1;
                    count<=count+1;
                    state_mul<=3;
                end
                3: begin
                    extmem[0]<= {2'b0,add_out};
                    if(count == WIDTH) state_mul<=4;
                    else state_mul<=1;
                end
                4: begin
                    mult_rdy<=1;
                    state_mul<=0;
                    prev_req<=mult_req;
                end
            endcase
        end
            
    end


    // modmul stuff

    logic [2:0]            state_mul;
    logic [WIDTH-1:0]      mult_mem_a, mult_mem_b;
    logic [$clog2(WIDTH):0] count;
    logic prev_req, mult_req, mult_rdy;

    logic [WIDTH-1:0] add_out;
    logic add_ctrl;

    //modadd

    logic [WIDTH:0] val_1;
    logic [WIDTH-1:0] val_2;

    always_comb begin
        if(add_ctrl) begin
            val_1 = (WIDTH+1)'({1'b0,extmem[0]} - {1'b0,extmem[1]});
            val_2 = val_1[WIDTH-1:0] + mem[9];
            add_out = (extmem[1]>=extmem[0]) ? val_2[WIDTH-1:0] : val_1[WIDTH-1:0];
        end else begin
            val_1 = (WIDTH+1)'({1'b0,extmem[0]} + {1'b0,extmem[1]});
            val_2 = val_1[WIDTH-1:0] - mem[9];
            add_out = (val_1>={1'b0,mem[9]}) ? val_2[WIDTH-1:0] : val_1[WIDTH-1:0];
        end
    end


endmodule
