module instruction_memory #( parameter INIT_FILE = "")(

	input logic [31:0] pc, 
	output logic [31:0] instruction
);

logic [31:0] memory [0:255];

initial begin
	if (INIT_FILE != "")
		$readmemh(INIT_FILE, memory);
end

assign instruction = memory[pc[9:2]];

endmodule
