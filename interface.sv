interface dut_if;
  logic        clk;
  logic        rst;

  // write channel (master -> slave)
  logic        wr_valid;
  logic [7:0]  wr_data;
  logic [7:0]  wr_addr;
  logic [3:0]  awid;
  logic        wr_rdy;

  // write response (slave -> master)
  logic        wr_resp_valid;
  logic [3:0]  wr_resp_id;
  logic [1:0]  wr_resp;

  // read channel (master -> slave)
  logic        rd_valid;
  logic [7:0]  rd_addr;
  logic [3:0]  arid;
  logic        rd_rdy;

  // read response (slave -> master)
  logic        rd_resp_valid;
  logic [3:0]  rd_resp_id;
  logic [1:0]  rd_resp;
  logic [7:0]  rd_data;
endinterface