module tb;
 
  dut_if vif();
  
  axi_ooo dut (.clk(vif.clk), .rst(vif.rst), .wr_valid(vif.wr_valid), .wr_data(vif.wr_data), .wr_addr(vif.wr_addr), .awid(vif.awid), .wr_rdy(vif.wr_rdy),
               .wr_resp_valid(vif.wr_resp_valid), .wr_resp_id(vif.wr_resp_id), .wr_resp(vif.wr_resp),
               .rd_valid(vif.rd_valid), .rd_addr(vif.rd_addr), .arid(vif.arid), .rd_rdy(vif.rd_rdy),
               .rd_resp_valid(vif.rd_resp_valid), .rd_resp_id(vif.rd_resp_id), .rd_resp(vif.rd_resp), .rd_data(vif.rd_data));

  // Initial reset
    initial begin
        vif.rst     = 0;
        vif.wr_valid = 0;
        vif.wr_data = '0;
        vif.wr_addr = '0;
        vif.awid = '0;
        vif.rd_valid = 0;
        vif.rd_addr = '0;
        vif.arid = '0;
    end

  // Clock generation
    initial begin
        vif.clk = 0;
        forever begin
            #5 vif.clk = ~vif.clk;
        end
    end

initial 
  begin
  uvm_config_db #(virtual dut_if)::set(null, "*", "vif", vif);
  run_test("test"); 
  end
 
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end

endmodule
