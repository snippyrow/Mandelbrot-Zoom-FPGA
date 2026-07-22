module pll_video (
    input clk_in,
    output clk_out,
    output locked
);

    // I have no clue how this works. Better figure it out soon.
    // Run 'icepll -i 50 -o 25.175' to get the correct values.
`ifdef SYNTHESIS
    SB_PLL40_CORE #(
        .FEEDBACK_PATH("SIMPLE"),
        .DIVR(4'b0100), // Reference divider of 1
        .DIVF(7'b1010000),
        .DIVQ(3'b101),
        .FILTER_RANGE(3'b001)
    ) pll_inst (
        .REFERENCECLK(clk_in),
        .PLLOUTCORE(clk_out),
        .LOCK(locked),
        .RESETB(1'b1),
        .BYPASS(1'b0)
    );
`else // If not in synthesis, route the clock output directly to the input.
    assign clk_out = clk_in;
    assign locked = 1'b0;
`endif

endmodule // PLL
