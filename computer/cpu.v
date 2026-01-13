`default_nettype none

module cpu(
  input wire clock,
  input wire [15:0] in_m,
  input wire [15:0] instruction,
  input wire reset,
  input wire hold,
  output wire [15:0] out_m,
  output wire write_m, 
  output wire [14:0] address_m,
  output wire [14:0] pc
);

// wires and registers
// mux wires
wire [15:0] mux16_before_a_register_a;
wire [15:0] mux16_before_a_register_b;
wire mux16_before_a_register_sel;
wire [15:0] mux16_before_a_register_y;

wire [15:0] mux16_before_alu_a;
wire [15:0] mux16_before_alu_b;
wire mux16_before_alu_sel;
wire [15:0] mux16_before_alu_y;

// register wires
wire [15:0] a_register_in;
wire a_register_load;
wire [15:0] a_register_out;

wire [15:0] d_register_in;
wire d_register_load;
wire [15:0] d_register_out;

wire [15:0] pc_register_in;
wire pc_register_increment;
wire pc_register_load;
wire pc_register_reset;
wire [15:0] pc_register_out;

// ALU wires
wire [15:0] x;
wire [15:0] y;
wire zx;
wire nx;
wire zy;
wire ny;
wire f;
wire no;
wire [15:0] out;
wire zr;
wire ng;

// control wires
wire is_a_instruction;
wire load_a_register_requested;
wire load_a_register;
wire load_a_c_instruction;
wire load_d_register_requested;
wire load_d_register;

wire out_not_neg;
wire out_not_zero;
wire out_pos;
wire jump_neg;
wire jump_zero;
wire jump_neg_or_zero;
wire jump_pos;
wire jump_requested;
wire jump;

wire write_m_requested;

wire run;

// connections
// break instruction into bits
wire is_c_instruction = instruction[15];
wire a_bit = instruction[12];
wire c5_bit = instruction[11];
wire c4_bit = instruction[10];
wire c3_bit = instruction[9];
wire c2_bit = instruction[8];
wire c1_bit = instruction[7];
wire c0_bit = instruction[6];
wire dest_a_bit = instruction[5];
wire dest_d_bit = instruction[4];
wire dest_m_bit = instruction[3];
wire jump_neg_bit = instruction[2];
wire jump_zero_bit = instruction[1];
wire jump_pos_bit = instruction[0];

// connect parts
assign mux16_before_a_register_a = out;
assign mux16_before_a_register_b = instruction;
assign mux16_before_a_register_sel = is_a_instruction; // if sel is 0, pick a, else b

assign a_register_in = mux16_before_a_register_y;
assign a_register_load = load_a_register;

assign d_register_in = out;
assign d_register_load = load_d_register;

assign mux16_before_alu_a = a_register_out;
assign mux16_before_alu_b = in_m;
assign mux16_before_alu_sel = a_bit;

assign zx = c5_bit;
assign nx = c4_bit;
assign zy = c3_bit;
assign ny = c2_bit;
assign f = c1_bit;
assign no = c0_bit;
assign x = d_register_out;
assign y = mux16_before_alu_y;

assign pc_register_in = a_register_out;
assign pc_register_reset = reset;
// jump? combo logic via jump bits, ng zr outputs
// is_c_instruction & (jump less & ng) | (jump eq & zr) | (jump pos & ~((eq|zr)))
assign pc_register_increment = run; // ignored unless reset, load vanish

assign out_m = out;

assign address_m = a_register_out[14:0];
assign pc = pc_register_out[14:0];

// parts
// control logic
not1 u_is_a_instruction(.a(is_c_instruction), .y(is_a_instruction));

and2 u_out_m_requested(.a(dest_m_bit), .b(is_c_instruction), .y(write_m_requested));
and2 u_out_m(.a(write_m_requested), .b(run), .y(write_m));

and2 u_load_a_c_instruction(.a(is_c_instruction), .b(dest_a_bit), .y(load_a_c_instruction));
or2 u_load_a_register_requested(.a(is_a_instruction), .b(load_a_c_instruction), .y(load_a_register_requested));
and2 u_load_a_register(.a(load_a_register_requested), .b(run), .y(load_a_register));

and2 u_load_d_register_requested(.a(is_c_instruction), .b(dest_d_bit), .y(load_d_register_requested));
and2 u_load_d_register(.a(load_d_register_requested), .b(run), .y(load_d_register));

and2 u_pc_load(.a(jump), .b(run), .y(pc_register_load));

not1 u_out_not_negative(.a(ng), .y(out_not_neg));
not1 u_out_not_zero(.a(zr), .y(out_not_zero));
and2 u_out_positive(.a(out_not_neg), .b(out_not_zero), .y(out_pos));
and2 u_jump_neg(.a(ng), .b(jump_neg_bit), .y(jump_neg));
and2 u_jump_zero(.a(zr), .b(jump_zero_bit), .y(jump_zero));
and2 u_jump_pos(.a(out_pos), .b(jump_pos_bit), .y(jump_pos));
or2 u_jump_neg_or_zero(.a(jump_neg), .b(jump_zero), .y(jump_neg_or_zero));
or2 u_jump_requested(.a(jump_neg_or_zero), .b(jump_pos), .y(jump_requested));
and2 u_jump(.a(jump_requested), .b(is_c_instruction), .y(jump));

not1 u_run(.a(hold), .y(run));

// registers
register16 u_a_register(
  .clock(clock),
  .in(a_register_in),
  .load(a_register_load),
  .out(a_register_out)
);

register16 u_d_register(
  .clock(clock),
  .in(d_register_in),
  .load(d_register_load),
  .out(d_register_out)
);

counter16 u_pc(
  .clock(clock),
  .in(pc_register_in),
  .increment(pc_register_increment),
  .load(pc_register_load),
  .reset(pc_register_reset),
  .out(pc_register_out)
);

mux16 u_mux16_before_a_register(
  .a(mux16_before_a_register_a),
  .b(mux16_before_a_register_b),
  .sel(mux16_before_a_register_sel),
  .y(mux16_before_a_register_y)
);

mux16 u_mux16_before_alu(
  .a(mux16_before_alu_a),
  .b(mux16_before_alu_b),
  .sel(mux16_before_alu_sel),
  .y(mux16_before_alu_y)
);

// alu
alu u_alu(
  .x(x),
  .y(y),
  .zx(zx),
  .nx(nx),
  .zy(zy),
  .ny(ny),
  .f(f),
  .no(no),
  .out(out),
  .zr(zr),
  .ng(ng)
);

endmodule  // cpu