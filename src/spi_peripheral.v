module spi_peripheral (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       nCS,
    input  wire       COPI,
    input  wire       SCLK,

    output reg  [7:0] en_reg_out_7_0,
    output reg  [7:0] en_reg_out_15_8,
    output reg  [7:0] en_reg_pwm_7_0,
    output reg  [7:0] en_reg_pwm_15_8,
    output reg  [7:0] pwm_duty_cycle
);

    reg nCS_sync1,  nCS_sync2;
    reg SCLK_sync1, SCLK_sync2;
    reg COPI_sync1, COPI_sync2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            nCS_sync1  <= 1'b1;
            nCS_sync2  <= 1'b1;
            SCLK_sync1 <= 1'b0;
            SCLK_sync2 <= 1'b0;
            COPI_sync1 <= 1'b0;
            COPI_sync2 <= 1'b0;
        end else begin
            nCS_sync1  <= nCS;
            nCS_sync2  <= nCS_sync1;

            SCLK_sync1 <= SCLK;
            SCLK_sync2 <= SCLK_sync1;

            COPI_sync1 <= COPI;
            COPI_sync2 <= COPI_sync1;
        end
    end


    reg SCLK_prev;
    wire SCLK_rising = (SCLK_sync2 == 1'b1) && (SCLK_prev == 1'b0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            SCLK_prev <= 1'b0;
        end else begin
            SCLK_prev <= SCLK_sync2;
        end
    end

    reg nCS_prev;
    wire nCS_negedge = (nCS_sync2 == 1'b0) && (nCS_prev == 1'b1);
    wire nCS_posedge = (nCS_sync2 == 1'b1) && (nCS_prev == 1'b0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            nCS_prev <= 1'b1;
        end else begin
            nCS_prev <= nCS_sync2;
        end
    end

  
    reg [15:0] shift_register;
    reg [4:0]  bit_count;
    reg        frame;
    reg        transaction;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_register <= 16'd0;
            bit_count <= 5'd0;
            frame <= 1'b0;
            transaction <= 1'b0;
        end else begin
         
            if (nCS_negedge) begin
                bit_count <= 5'd0;
                frame <= 1'b0;
            end

          
            if (nCS_sync2 == 1'b0 && SCLK_rising) begin
                shift_register <= {shift_register[14:0], COPI_sync2};
                bit_count      <= bit_count + 5'd1;
            end

 
            if (nCS_posedge) begin
                if (bit_count == 5'd16)
                    frame <= 1'b1;
                bit_count <= 5'd0;
            end
        end
    end

    localparam MAX_ADDRESS = 7'd4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            en_reg_out_7_0 <= 8'h00;
            en_reg_out_15_8 <= 8'h00;
            en_reg_pwm_7_0 <= 8'h00;
            en_reg_pwm_15_8 <= 8'h00;
            pwm_duty_cycle <= 8'h00;

        end else if (frame && !transaction) begin
            if (shift_register[15] == 1'b1 && shift_register[14:8] <= MAX_ADDRESS) begin
                case (shift_register[14:8])
                    7'd0: en_reg_out_7_0 <= shift_register[7:0];
                    7'd1: en_reg_out_15_8 <= shift_register[7:0];
                    7'd2: en_reg_pwm_7_0 <= shift_register[7:0];
                    7'd3: en_reg_pwm_15_8 <= shift_register[7:0];
                    7'd4: pwm_duty_cycle <= shift_register[7:0];
                    default: ;
                endcase
            end

            transaction <= 1'b1;

        end else if (transaction) begin
            transaction <= 1'b0;
        end
    end

endmodule
