
module litBits
	(
		CLOCK_50,						//	On Board 50 MHz
		// Your inputs and outputs here

		// The ports below are for the VGA output.  Do not change.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B   						//	VGA Blue[9:0]
	);

	input			CLOCK_50;				//	50 MHz

	// Declare your inputs and outputs here
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[7:0]	VGA_R;   				//	VGA Red[7:0] Changed from 10 to 8-bit DAC
	output	[7:0]	VGA_G;	 				//	VGA Green[7:0]
	output	[7:0]	VGA_B;   				//	VGA Blue[7:0]
	
	// Create the colour, x, y and writeEn wires that are inputs to the controller.

	wire [2:0] colour;
	wire [7:0] x;
	wire [6:0] y;
	wire writeEn;

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	
//uncomment for fpga

	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";
	

//	// Put your code here. Your code should produce signals x,y,colour and writeEn
	// for the VGA controller, in addition to any other functionality your design may require.
	
	//wire writeen goes to plot
	
endmodule
	
	
module graphicsDP(clock, resetn, record,//clock reset record
		drawCursorEn, drawNoteEn, eraseCursor, move, drawBackground, unDone, blacken,// and input signals
		data, //data from RAM
		plot, x, y, colour, //outputs to VGA adapter
		track, note, sample,// outputs to ram
		done //output to FSM
	);
	
	input clock, resetn, move, drawCursorEn, drawNoteEn, eraseCursor, drawBackground, unDone, blacken;
	input [?:?] data;
	
	output plot;
	output [7:0] x;
	output [6:0] y;
	output [2:0] colour;
	
	//for accessing data
	output reg [?:?] track; //TODO: we need to discuss with dylan what these values are
	output reg [?:?] note;
	output reg [?:?] sample;
	
	output reg done;

	reg [6:0] cursorX = 0; //the cursor really starts at the 32nd pixel
									//so we need one less bit to describe where it is since 128 locations = 2^7
	reg [6:0] cursorY = 0;
									
	reg [7:0] screenX = 0;
	reg [6:0] screenY = 0;
	
	cursorRate cr(clock, tick);
	
	always @(posedge clock)
		begin
			plot <= 0; //have to deliberately plot
			if (!resetn)
				begin
					cursorX = 0;
					track = 0;
					note = 0;
					sample = 0;
					done = 0;
				end
			//unchecking the done signal
			if (unDone) done <= 0;
			//quickly making everything black to simplify resetting and drawing a background
			if (blacken)
				begin
					plot <= 1;
					if (screenX == 8'd159 && screenY == 7'd119)
						begin
							screenX = 0;
							screenY = 0;
							x = 8'd159;
							y = 7'd119;
							colour = 0;
							done = 1;
						end
					else
						begin
							x <= screenX;
							y <= screenY;
							colour <= 3'b0;
							done <= 0;
							if (screenX == 8'd159)
								begin
									screenX <= 0;
									screenY <= screenY + 1'b1;
								end
							else
								begin
									screenX <= screenX + 1'b1;
								end
						end
				end
			else if (drawBackground)
				begin
					x <= 30;
					y <= screenY + 7'd16;
					colour <= 3'b101;
					plot <= 1;
					if (screenY == 7'd103)
						begin
							screenY <= 0;
							done <= 1;
						end
					else screenY <= screenY + 1'b1;
				end
			else if (drawCursorEn)
				begin
					plot <= 1;
					x = cursorX + 7'd32;
					y = cursorY + 7'd16;
					colour  = 3'b110;
					if (cursorY == 7'd103)
						begin
							done <= 1;
							cursorY <= 0;
						end
					else cursorY <= cursorY + 1'b1;
				end
			else if (drawNoteEn)
				
				//TODO: check on dylan and confirm method for accessing track
				
				begin
					if (cursorX != 0) //this just prevents writing notes one pixel too far to the left since our convention is writing after cursor passes over
						begin
							
						end
				end
			else if (eraseCursor)
				begin
					plot <= 1;
					x = cursorX;
					y = cursorY;
					colour = 0;
					
					if (cursorY == 7'd103)
						begin
							done <= 1;
						end
					else cursorY <= cursorY + 1'b1;		
				end
			else if (move)
				begin
					cursorX <= cursorX + 1'b1;
				end
		end
endmodule
	
	
	
module graphicsFSM(clock, resetn, tick, load,  done,
		drawCursorEn, drawNoteEn, eraseCursor, move, drawBackground, unDone, blacken//some output control needs to go here
		);

	input clock, resetn, tick, load; //tick is the .5 s timer to draw the next pixel
	input load; //if the ram is being written to
	
	output reg drawCursorEn, drawNoteEn, eraseCursor, move, drawBackground, unDone, blacken;
	
	reg [2:0] state, nextState;
	assign state = 0;
	//State list
	localparam
				RESET_STATE = 4'd0,
				BLACKEN = 4'd1,
				UNDONE1 = 4'd8,
				DRAW_BACKGROUND = 4'd2,
				WAIT_FOR_LOADN = 4'd3,
				DRAW_CURSOR = 4'd4,
				DRAW_NOTES = 4'd9,
				WAIT_FOR_PIXEL = 4'd5,
				ERASE_CURSOR = 4'd6,
				MOVE_CURSOR = 4'd7;
				
	always @(clock posedge)
		begin
			if (!resetn) state <= 0;
			else state <= nextState;
		end
		
	always @(*)
		begin
		//set all output to zero, to be deliberate about what is being done
		drawBackground <= 0;
		drawCursorEn <= 0; 
		drawNoteEn <= 0;
		eraseCursor <= 0;
		move <= 0;
		unDone <= 0;
		blacken <= 0;
	//FSM logic
		begin
			if (state == RESET_STATE) nextState <= BLACKEN;
			else if (state == BLACKEN)
				begin
					blacken <= 1;
					nextState <= (done) ? UNDONE1 : BLACKEN;
				end
			else if (state == UNDONE1)
				begin
					unDone <= 1;
					nextState <= DRAW_BACKGROUND;
			else if (state == DRAW_BACKGROUND)
				begin
					drawBackground <= 1;
					nextState <= (done) ? DRAW_BACKGROUND : WAIT_FOR_LOADN;
				end
			else if (state == WAIT_FOR_LOADN)
				begin
					unDone <= 1;
					nextState <= (load) ? WAIT_FOR_LOADN : DRAW_CURSOR;
				end
			else if (state == DRAW_CURSOR)
				begin
					drawCursorEn <= 1;
					nextState <= (done) ? UNDONE2 : DRAW;
				end
			else if (state == UNDONE2)
				begin
					unDone <= 1;
					nextState <= DRAW_NOTES;
				end
			else if (state == DRAW_NOTES)
				begin
					drawNoteEn <= 1;
					next_state <= (done) ? WAIT_FOR_PIXEL : DRAW_NOTES;
				end
			else if (state == WAIT_FOR_PIXEL)
				begin
					unDone <= 1;
					nextState <= (tick) ? ERASE_CURSOR : WAIT_FOR_PIXEL;
				end
			else if (state == ERASE_CURSOR)
				begin
					eraseCursor <= 1;
					nextState <= MOVE_CURSOR;
				end
			else if (state == MOVE_CURSOR)
				begin
					unDone = 1;
					move <= 1;
					nextState <= WAIT_FOR_LOADN;
				end
		end
		end
endmodule


module cursorRate(clock, q);
	input clock;
	output reg q = 0;
	reg [24:0] counter = 25'b1011111010111100001000000;
	
	always @(clock posedge)
		begin
			if (!resetn)
				begin
					counter <= 25'b1011111010111100001000000;
					q <= 0;
				end
			else if (counter == 0)
				begin
					counter <= 25'b1011111010111100001000000;
					q <= 1;
				end
			else
				begin
					counter <= counter - 1'b1;
					q <= 0;
				end
		end
endmodule
	
	
	
	

	
	