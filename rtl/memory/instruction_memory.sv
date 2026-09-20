module instruction_memory #( parameter INIT_FILE = "")(

	input logic [31:0] pc, 
	output logic [31:0] instruction
);

// 4 KiB instruction storage: 1024 words of 32 bits.
logic [31:0] memory [0:1023];

initial begin
	if (INIT_FILE != "")
		$readmemh(INIT_FILE, memory);
end

assign instruction = memory[pc[11:2]];

endmodule
