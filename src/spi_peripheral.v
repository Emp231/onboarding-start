`default_nettype none

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

    // Synchronize inputs to clk
    reg nCS_sync1, nCS_sync2;
    reg SCLK_sync1, SCLK_sync2;
    reg COPI_sync1, COPI_sync2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            nCS_sync1 <= 1'b1; nCS_sync2 <= 1'b1;
            SCLK_sync1 <= 1'b0; SCLK_sync2 <= 1'b0;
            COPI_sync1 <= 1'b0; COPI_sync2 <= 1'b0;
        end else begin
            nCS_sync1 <= nCS;
            nCS_sync2 <= nCS_sync1;
            SCLK_sync1 <= SCLK;
            SCLK_sync2 <= SCLK_sync1;
            COPI_sync1 <= COPI;
            COPI_sync2 <= COPI_sync1;
        end
    end

    // Detect edges
    reg SCLK_prev, nCS_prev;
    wire SCLK_rising = SCLK_sync2 & ~SCLK_prev;
    wire nCS_falling = ~nCS_sync2 & nCS_prev;
    wire nCS_rising  = nCS_sync2 & ~nCS_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            SCLK_prev <= 1'b0;
            nCS_prev  <= 1'b1;
        end else begin
            SCLK_prev <= SCLK_sync2;
            nCS_prev  <= nCS_sync2;
        end
    end

    // SPI shift register and bit counter
    reg [15:0] shift_reg;
    reg [4:0] bit_count;
    reg transaction;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 16'd0;
            bit_count <= 5'd0;
            transaction <= 1'b0;
        end else begin
            // Start new frame
            if (nCS_falling) begin
                bit_count <= 0;
                transaction <= 1'b0;
            end

            // Shift in data
            if (~nCS_sync2 && SCLK_rising) begin
                shift_reg <= {shift_reg[14:0], COPI_sync2};
                bit_count <= bit_count + 1;
            end

            // Latch outputs on frame completion
            if (nCS_rising && bit_count == 16 && !transaction) begin
                if (shift_reg[15] == 1'b1 && shift_reg[14:8] <= 7'd4) begin
                    case (shift_reg[14:8])
                        7'd0: en_reg_out_7_0  <= shift_reg[7:0];
                        7'd1: en_reg_out_15_8 <= shift_reg[7:0];
                        7'd2: en_reg_pwm_7_0  <= shift_reg[7:0];
                        7'd3: en_reg_pwm_15_8 <= shift_reg[7:0];
                        7'd4: pwm_duty_cycle   <= shift_reg[7:0];
                    endcase
                end
                transaction <= 1'b1; // prevent double write
            end
        end
    end

endmodule
