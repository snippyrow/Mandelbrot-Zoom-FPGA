module top (
    output logic led,         // high = LED on
    input wire clk_core,

    output wire hsync_out,
    output wire vsync_out,

    output logic [2:0] vga_out_r,
    output logic [2:0] vga_out_g,
    output logic [1:0] vga_out_b,

    output logic vga_clk_out, // Test for makefile
    output logic vga_blank_out,

    // CPU test
    `ifdef VERILATOR
        input logic cpu_test_clk
    `endif
);
    
    // Findings? The real version seems to be very inconsistent with the simulation. Doing the stripe test revealed that the CPU does in fact do something at the expected spot, but only sometimes. The screen render is completely different than the sim and needs to be made much more stable. More accurate timing diagrams must be done.

    reg [24:0] counter;       // 25 bits is enough (2^25 = 33.5M > 25M)
    always @(posedge clk_core) begin
        if (counter == 25_000_000 - 1) begin
            counter <= 0;
            led     <= ~led;      // Toggle LED every 0.5 seconds
        end else begin
            counter <= counter + 1;
        end
    end
    
    // Initiate PLL for VGA
    wire vga_clk_in;
    
    // Code for mandelbrot framebuffer
    logic [7:0] framebuffer [0:9599]; // Frame memory & normal memory are shared.

    logic [7:0] frame_out;
    logic [13:0] frame_adrbus;

    logic [16:0] frame_wr_adbus;
    logic frame_in;
    logic mandel_we;

    wire mandel_clk;

    // Code for framebuffer
    always_ff @(posedge vga_clk_in) begin
        frame_out <= framebuffer[frame_adrbus];
    end

    // If the address is greater than 255, add to framebuffer instead.
    always_ff @(posedge clk_core) begin
        if (mandel_we) begin
            framebuffer[frame_wr_adbus[16:3]][frame_wr_adbus[2:0]] <= frame_in;
        end
    end

    pll_video pll (
        .clk_in(clk_core),
        .clk_out(vga_clk_in),
        .locked()
    );
    
    vga_buffered_mandel #(
        .DEPTH_R(3),
        .DEPTH_G(3),
        .DEPTH_B(2)
    ) tty (
        .vga_clk(vga_clk_in),
        .vga_clk_out(vga_clk_out),
        .px(),
        .py(),
        .hsync(hsync_out),
        .vsync(vsync_out),
        .de(vga_blank_out),
        .vga_r(vga_out_r),
        .vga_g(vga_out_g),
        .vga_b(vga_out_b),
        .buffer_read_addr(frame_adrbus),
        .pixels(frame_out)
    );

    mandelbrot_zoom mandel (
        .clk(clk_core),
        .pixel_dbus(frame_in),
        .pixel_adbus(frame_wr_adbus),
        .we(mandel_we)
    );
    

endmodule // Top module finished!
