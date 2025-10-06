// Out Of Ordering rules :
// 1. WR/RD using same id are always served in order
// 2. Different ID's can be served out of order
// 3. No ordering required between WR and READ Channels for the same ID

module axi_ooo (
  input  logic        clk,
  input  logic        rst,

  // write channel (master -> slave)
  input  logic        wr_valid,
  input  logic [7:0]  wr_data,
  input  logic [7:0]  wr_addr,
  input  logic [3:0]  awid,
  output logic        wr_rdy,

  // write response (slave -> master)
  output logic        wr_resp_valid,
  output logic [3:0]  wr_resp_id,
  output logic [1:0]  wr_resp,

  // read channel (master -> slave)
  input  logic        rd_valid,
  input  logic [7:0]  rd_addr,
  input  logic [3:0]  arid,
  output logic        rd_rdy,

  // read response (slave -> master)
  output logic        rd_resp_valid,
  output logic [3:0]  rd_resp_id,
  output logic [1:0]  rd_resp,
  output logic [7:0]  rd_data
);

  // -------------------------
  // types and storage
  // -------------------------
  typedef struct packed {
    logic [7:0] wr_addr;
    logic [7:0] wr_data;
    logic       valid;
    logic [4:0] delay;
  } wr_struct;

  typedef struct packed {
    logic [7:0] rd_addr;
    logic       valid;
    logic [4:0] delay;
  } rd_struct;

  // 256 x 8-bit memory
  logic [7:0] mem [0:255];

  // per-ID bounded pending queues (16 IDs, max 8 entries each)
  wr_struct wr_arr [0:15][$:8];
  rd_struct rd_arr [0:15][$:8];


  // -------------------------
  // synchronous logic
  // -------------------------
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      // reset outputs
      wr_resp_valid <= 1'b0;
      wr_resp_id    <= '0;
      wr_resp       <= 2'b00;

      rd_resp_valid <= 1'b0;
      rd_resp_id    <= '0;
      rd_resp       <= 2'b00;
      rd_data       <= '0;

      wr_rdy <= 1'b1;
      rd_rdy <= 1'b1;

      // clear queues
      foreach (wr_arr[i]) wr_arr[i].delete();
      foreach (rd_arr[j]) rd_arr[j].delete();

      // clear memory
      for (int m = 0; m < 256; m++) mem[m] <= '0;

    end else begin
      // default outputs
      wr_resp_valid <= 1'b0;
      wr_resp_id    <= '0;
      wr_resp       <= 2'b00;

      rd_resp_valid <= 1'b0;
      rd_resp_id    <= '0;
      rd_resp       <= 2'b00;
      rd_data       <= '0;

      // assume ready unless backpressure discovered below
      wr_rdy <= 1'b1;
      rd_rdy <= 1'b1;

      // -------------------------
      // decrement delays (simulate variable latency)
      // -------------------------
      foreach (wr_arr[id]) begin
        for (int k = 0; k < wr_arr[id].size(); k++)
          if (wr_arr[id][k].delay > 0)
            wr_arr[id][k].delay = wr_arr[id][k].delay - 1;
      end

      foreach (rd_arr[id]) begin
        for (int k = 0; k < rd_arr[id].size(); k++)
          if (rd_arr[id][k].delay > 0)
            rd_arr[id][k].delay = rd_arr[id][k].delay - 1;
      end

      // -------------------------
      // enqueue new incoming requests
      // -------------------------
      if (wr_valid && wr_rdy)
        wr_arr[awid].push_back('{wr_addr, wr_data, 1'b1, $urandom_range(0,16)});

      if (rd_valid && rd_rdy)
        rd_arr[arid].push_back('{rd_addr, 1'b1, $urandom_range(0,16)});

      // -------------------------
      // process one write completion per cycle
      // -------------------------
      foreach (wr_arr[id]) begin
        if (wr_arr[id].size() > 0 && wr_arr[id][0].valid && wr_arr[id][0].delay == 0) begin
          if (wr_arr[id][0].wr_addr <= 8'hff) begin
            mem[wr_arr[id][0].wr_addr] <= wr_arr[id][0].wr_data;
            wr_resp_valid <= 1'b1;
            wr_resp_id    <= id;
            wr_resp       <= 2'b00; // OKAY
          end else begin
            wr_resp_valid <= 1'b1;
            wr_resp_id    <= id;
            wr_resp       <= 2'b01; // error
          end
          wr_arr[id].pop_front();
          break; // single write completion per cycle
        end
      end

      // -------------------------
      // process one read completion per cycle
      // -------------------------
      foreach (rd_arr[id]) begin
        if (rd_arr[id].size() > 0 && rd_arr[id][0].valid && rd_arr[id][0].delay == 0) begin
          if (rd_arr[id][0].rd_addr <= 8'hff) begin
            rd_data       <= mem[rd_arr[id][0].rd_addr];
            rd_resp_valid <= 1'b1;
            rd_resp_id    <= id;
            rd_resp       <= 2'b00;
          end else begin
            rd_resp_valid <= 1'b1;
            rd_resp_id    <= id;
            rd_resp       <= 2'b01;
          end
          rd_arr[id].pop_front();
          break; // single read completion per cycle
        end
      end

      // -------------------------
      // backpressure: if any queue is full, deassert ready
      // -------------------------
      foreach (wr_arr[i]) if (wr_arr[i].size() >= 8) begin wr_rdy <= 1'b0; break; end
      foreach (rd_arr[j]) if (rd_arr[j].size() >= 8) begin rd_rdy <= 1'b0; break; end
    end
  end
endmodule


