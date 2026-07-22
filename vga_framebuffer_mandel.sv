module vga_buffered_mandel #(
    // 640x480 -> 320x240 1BPP display.
	// Designed to work with the ADV7123 DAC.
    parameter DEPTH_R = 3,
	parameter DEPTH_G = 3,
	parameter DEPTH_B = 2
) (
	input wire vga_clk, // VGA Clock (probably derived from the PLL)
	output logic vga_clk_out, // For ADV7123

    // Reveal the pixel coordinates in rectangular form.
	output logic [9:0] px,
	output logic [9:0] py,

    // Horizontal and vertical sync
	output logic vsync,
	output logic hsync,

    // Blanking interval
	output logic de, // Wire to nBLANK on the ADC.

    // Output R/G/B color channels for the display.
	output logic [DEPTH_R-1:0] vga_r,
	output logic [DEPTH_G-1:0] vga_g,
	output logic [DEPTH_B-1:0] vga_b,

	// Sprite memory will return each line of a character. Read clock is clocked the same as the vga clock.
	output logic [13:0] buffer_read_addr,
	input wire [7:0] pixels // Read eight pixels at once
);
	// 640x480 @ 60Hz
    // All variables are subtracted by one for stability
	localparam HA_END = 639; // End of horizontal visible area
	localparam HS_STA = HA_END + 16; // Start of horizontal sync
	localparam HS_END = HS_STA + 96; // End of horizontal sync
	localparam LINE = 799; // End of line

	localparam VA_END = 479; // End of vertical frame
	localparam VS_STA = VA_END + 10; // Start of vertical sync
	localparam VS_END = VS_STA + 2; // End of vertical sync
	localparam SCREEN = 524; // End of frame

	// Generate hsync and vsync signals
	always_comb begin
		hsync = ~(px >= HS_STA && px < HS_END);
		vsync = ~(py >= VS_STA && py < VS_END);
		de = (px <= HA_END && py <= VA_END); // Invert blanking signal for ADV7123

		vga_clk_out = vga_clk;

		// Assign either white or black.
		vga_r = (de && pixels[px[3:1]]) ? '1 : '0;
		vga_g = (de && pixels[px[3:1]]) ? '1 : '0;
		vga_b = (de && pixels[px[3:1]]) ? '1 : '0;
	end
	
	// Count the x, y positions
	always_ff @(posedge vga_clk) begin
		// Pixel counter
		if (px == LINE) begin
			px <= 0;
			py <= (py == SCREEN) ? 0 : py + 1;
			// Prefetch next area
			if (py == SCREEN) begin
                buffer_read_addr <= 14'd0; // Absolute top-left of frame buffer
            end else begin
                buffer_read_addr <= ((py[9:1] + 1'b1) * 14'd40); // Start of next line
            end
		end else begin
			px <= px + 1;

			if (px < HA_END - 10'd8) begin
                if (px[3:1] == 3'd7) begin
                    buffer_read_addr <= (py[9:1] * 14'd40) + px[9:4] + 1'b1;
                end
            end
		end
	end
endmodule
