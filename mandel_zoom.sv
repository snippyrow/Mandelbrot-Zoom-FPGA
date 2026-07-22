module mandelbrot_zoom (
    input wire clk,
    output logic pixel_dbus,
    output logic [16:0] pixel_adbus,
    output logic we
);

/*
    Simple mandelbrot set renderer. Takes in a clock, has a write-enable, address bus and 1-bit pixel bus.
*/

// '24' macro helper functions
`define FIXED_SHIFT 23
`define FIXED_SCALE (1 << `FIXED_SHIFT) // 4096

`define FLOAT_TO_FIXED(x) (int'(x * `FIXED_SCALE))
`define ESC_RADIUS (4 * `FIXED_SCALE)

// Divide screen dimensions using bit-shifts
`define DIV_WIDTH(x) ((x >> 9) + (x >> 10) + (x >> 13) + (x >> 14) + (x >> 17) +(x >> 18) + (x >> 20))
`define DIV_HEIGHT(x) ((((x) >> 8) + ((x) >> 12) + ((x) >> 16) + ((x) >> 20)))

`define ITER_MAX 75

typedef logic signed [26:0] fixed24;

// Mandelbrot state machine
// Pixel loop index as integer forms
logic [8:0] px; // 320
logic [7:0] py; // 240

// Scaled starter pixel coordinates
fixed24 x_s, y_s;

// Current iteration pixel coordinate
fixed24 x;
fixed24 y;

wire [26:0] x_n_y = x + y;

fixed24 xs;
fixed24 ys;

logic [15:0] iteration;

logic [2:0] step; // State machine stepper

// Initialize frame counter.
reg [2:0] frame_init_cnt;

/*
    (0) Compute the square of the spacial pixel X
    (1) Compute the square of the spacial pixel Y
    (2) Compute the square of (x + y)
    (3) Final computation and radius check
*/

// Square module. Some of the precision WILL get truncated, but it seems to still work perceptably well.
fixed24 SQ_A_IN;
fixed24 SQ_B_IN;
fixed24 SQ_OUT;

fixed24 x_tmp;

fixed24 x_step_base;
fixed24 y_step_base;

fixed24 zoom;
fixed24 zoomed_x_step;
fixed24 zoomed_y_step;

fixed24 x_start;
fixed24 y_start;

always_comb begin
    SQ_OUT = fixed24'((signed'(54'(SQ_A_IN)) * signed'(54'(SQ_B_IN))) >>> `FIXED_SHIFT);
    // Always precompute during each stage
    //x_s = `FLOAT_TO_FIXED(-2.25) + ((px << 4) + (px << 4) + (px << 3) << 8);
    //y_s = `FLOAT_TO_FIXED(-1.25) + ((py << 5) + (py << 3) << 8);

    pixel_adbus = (py * 17'd320) + px;
end

initial begin
    px = 9'd0;
    py = 8'd0;
    iteration = 16'd0;
    step = 2'd0;
    x = 24'd0;
    y = 24'd0;
    x_s = `FLOAT_TO_FIXED(-2.25);
    y_s = `FLOAT_TO_FIXED(-1.25);

    frame_init_cnt = 0;
    zoom = `FLOAT_TO_FIXED(1.0);

    // Constants (basically)
    x_step_base = fixed24'(`DIV_WIDTH(`FLOAT_TO_FIXED(3.50)));
    y_step_base = fixed24'(`DIV_HEIGHT(`FLOAT_TO_FIXED(2.50)));
    
    zoomed_x_step = 0;
    zoomed_y_step = 0;
end

/*
    Implement a fixed-point 16-bit system.
    [15] = SIGN
    [14:12] = INTEGER
    [11:0] = FRACTION

    TODO: Implement zoom, 24-bit fixed-point, optimize..?
*/

always_ff @(posedge clk) begin
    if (frame_init_cnt <= 3'd5) begin
        // Set up Step size based on zoom.
        case (frame_init_cnt)
            3'd0: begin
                SQ_A_IN <= x_step_base;
                SQ_B_IN <= zoom;
            end
            3'd1: begin
                zoomed_x_step <= SQ_OUT;
                SQ_A_IN <= y_step_base;
                SQ_B_IN <= zoom;
            end
            3'd2: begin
                zoomed_y_step <= SQ_OUT;

                SQ_A_IN <= `FLOAT_TO_FIXED(1.75);
                SQ_B_IN <= zoom;
            end
            3'd3: begin
                x_start <= `FLOAT_TO_FIXED(-0.715) - SQ_OUT;
                SQ_A_IN <= `FLOAT_TO_FIXED(1.25);
                SQ_B_IN <= zoom;
            end
            3'd4: begin
                x_s <= x_start;
                y_s <= `FLOAT_TO_FIXED(0.350) - SQ_OUT;

                y_start <= `FLOAT_TO_FIXED(0.350) - SQ_OUT;

                // Compute zoom decrease exponentially
                SQ_A_IN <= zoom;
                SQ_B_IN <= `FLOAT_TO_FIXED(0.98);
            end
            3'd5: begin
                // Reset if broken
                zoom <= (zoom == 0) ? `FLOAT_TO_FIXED(1.0) : SQ_OUT;
            end
            default: ;
        endcase
        frame_init_cnt <= frame_init_cnt + 1;
    end else begin // Run normal loop if in frame
        case (step)
            3'd0: begin
                we <= 1'b0;
                SQ_A_IN <= x;
                SQ_B_IN <= x;
            end
            3'd1: begin
                SQ_A_IN <= y;
                SQ_B_IN <= y;
                xs <= SQ_OUT;
            end
            3'd2: begin
                SQ_A_IN <= x_n_y;
                SQ_B_IN <= x_n_y;
                ys <= SQ_OUT;
            end
            3'd3: begin
                x <= xs - ys + x_s;
                y <= SQ_OUT - xs - ys + y_s; // SQ_OUT is (x + y)
                
                // Terminate this loop
                if ((xs + ys) > `ESC_RADIUS || iteration >= `ITER_MAX) begin
                    iteration <= 0;
                    x <= 0;
                    y <= 0;

                    we <= 1;
                    pixel_dbus <= (iteration == `ITER_MAX) ? 1'b0 : 1'b1;

                    x_s <= x_s + zoomed_x_step;

                    if (px == 320) begin
                        px <= 0;
                        py <= (py == 240) ? 0 : py + 1;

                        x_s <= x_start;
                        y_s <= y_s + zoomed_y_step;


                        if (py == 240) begin
                            frame_init_cnt <= 0;
                            y_s <= y_start;
                        end
                    end else begin
                        px <= px + 1;
                    end
                end else begin
                    iteration <= iteration + 1;
                    we <= 1'b0;
                end
            end
            default: ;
        endcase
        step <= (step == 3'd3) ? 0: step + 1;
    end
end

endmodule