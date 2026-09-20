module data_memory #( 
	parameter INIT_FILE = ""
	) (
	input logic clk,
	input logic mem_write,
	input logic [31:0] address,
	input logic [31:0] write_data,
	input logic [2:0] funct3,
	output logic [31:0] read_data
);

// 1 KiB data storage: 256 words of 32 bits.
logic [31:0] memory [0:255];
logic [7:0] selected_byte;
logic [15:0] selected_half;

// Load constants and the initial-value copy used by C startup.
initial begin
    if (INIT_FILE != "")
        $readmemh(INIT_FILE, memory);
end

always_comb begin
	case(address[1:0])
		2'b00: selected_byte = memory[address[9:2]][7:0];
		2'b01: selected_byte = memory[address[9:2]][15:8];
		2'b10: selected_byte = memory[address[9:2]][23:16];
		2'b11: selected_byte = memory[address[9:2]][31:24];
		
		default: selected_byte = 8'b0;
	endcase
end

assign selected_half = (address[1]) ? memory[address[9:2]][31:16] : memory[address[9:2]][15:0];
 
localparam logic [2:0] LOAD_B  = 3'b000; // LB
localparam logic [2:0] LOAD_H  = 3'b001; // LH
localparam logic [2:0] LOAD_W  = 3'b010; // LW
localparam logic [2:0] LOAD_BU = 3'b100; // LBU
localparam logic [2:0] LOAD_HU = 3'b101; // LHU

always_comb begin
	case(funct3)
		LOAD_B: read_data = {{24{selected_byte[7]}}, selected_byte};
		LOAD_H: read_data = {{16{selected_half[15]}}, selected_half};
		LOAD_W: read_data = memory[address[9:2]];
		LOAD_BU: read_data = {24'b0, selected_byte};
		LOAD_HU: read_data = {16'b0, selected_half};

		default: read_data = 32'b0;
	endcase
end

localparam logic [2:0] STORE_B = 3'b000; // Store Byte
localparam logic [2:0] STORE_H = 3'b001; // Store Halfword
localparam logic [2:0] STORE_W = 3'b010; // Store Word


always_ff @(posedge clk) begin
	if (mem_write) begin
		case(funct3)
			STORE_B: begin
			    case (address[1:0])
			        2'b00: memory[address[9:2]][7:0]   <= write_data[7:0];
			        2'b01: memory[address[9:2]][15:8]  <= write_data[7:0];
			        2'b10: memory[address[9:2]][23:16] <= write_data[7:0];
			        2'b11: memory[address[9:2]][31:24] <= write_data[7:0];
			    endcase
			end

			STORE_H: begin
			    if (address[1])
			        memory[address[9:2]][31:16] <= write_data[15:0];
			    else
			        memory[address[9:2]][15:0] <= write_data[15:0];
			    end	
	
			STORE_W: memory[address[9:2]] <= write_data;

			default: ;
		endcase
	end
end

endmodule
