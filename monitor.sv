class mon extends uvm_monitor;
 `uvm_component_utils(mon)

  uvm_analysis_port#(transaction) send;
  transaction tr;
  virtual dut_if vif;

  int trans_captured;
  int wr_counter;
  int wr_completed_counter;
  uvm_event wr_complete_ev; // wr complete event

  function new(input string inst = "mon", uvm_component parent = null);
    super.new(inst,parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    send = new("send", this);
    if(!uvm_config_db#(virtual dut_if)::get(this,"","vif",vif)) `uvm_error("mon","Unable to access Interface");
  endfunction

  virtual task run_phase(uvm_phase phase);
   wr_counter = 0;
   wr_completed_counter = 0;
   wr_complete_ev = uvm_event_pool::get_global("ev_wr_complete");

   wait(vif.rst == 0);
   `uvm_info("MON", "Monitor Started....", UVM_LOW);
     forever begin
        @(posedge vif.clk);

        trans_captured = 0;
        tr = transaction::type_id::create("tr");

        // Capture Write Request
        if(vif.wr_valid && vif.wr_rdy && !vif.rd_valid) begin
          tr.op = WRITE;
          trans_captured = 1;
          tr.req_valid = 1;
          tr.wr_valid = vif.wr_valid;
          tr.wr_data = vif.wr_data;
          tr.wr_addr = vif.wr_addr;
          tr.awid = vif.awid;
          wr_counter++;
        end
       
        // Capture Read Request
        if(vif.rd_valid && vif.rd_rdy && !vif.wr_valid) begin
          tr.op = READ;
          trans_captured = 1;
          tr.req_valid = 1;
          tr.rd_valid = vif.rd_valid;
          tr.rd_addr = vif.rd_addr;
          tr.arid = vif.arid;
        end
       
        // Capture Write - Read Request in the same cycle
        if(vif.wr_valid && vif.wr_rdy && vif.rd_valid && vif.rd_rdy) begin
          tr.op = READ_WRITE;
          trans_captured = 1;
          tr.req_valid = 1;
          tr.wr_valid = vif.wr_valid;
          tr.wr_data = vif.wr_data;
          tr.wr_addr = vif.wr_addr;
          tr.awid = vif.awid;
          tr.req_valid = 1;
          tr.rd_valid = vif.rd_valid;
          tr.rd_addr = vif.rd_addr;
          tr.arid = vif.arid;
          wr_counter = wr_counter + 1;
        end

        // Capture Write Response
        if(vif.wr_resp_valid) begin
          tr.op_rsp = WR_RESP;
          trans_captured = 1;
          tr.rsp_valid = 1;
          tr.wr_resp_valid = vif.wr_resp_valid;
          tr.wr_resp_id = vif.wr_resp_id;
          tr.wr_resp = vif.wr_resp;
          wr_completed_counter = wr_completed_counter + 1; 
        end

        // Capture Read Response
        if(vif.rd_resp_valid) begin
          tr.op_rsp = RD_RESP;
          trans_captured = 1;
          tr.rsp_valid = 1;
          tr.rd_resp_valid = vif.rd_resp_valid;
          tr.rd_resp_id = vif.rd_resp_id;
          tr.rd_resp = vif.rd_resp;
          tr.rd_data = vif.rd_data;
        end
        
        // Capture Write - Read Response in the same cycle
        if(vif.wr_resp_valid && vif.rd_resp_valid) begin
          tr.op_rsp = RD_WR_RESP;
          trans_captured = 1;
          tr.rsp_valid = 1;
          tr.wr_resp_valid = vif.wr_resp_valid;
          tr.wr_resp_id = vif.wr_resp_id;
          tr.wr_resp = vif.wr_resp;
          tr.rd_resp_valid = vif.rd_resp_valid;
          tr.rd_resp_id = vif.rd_resp_id;
          tr.rd_resp = vif.rd_resp;
          tr.rd_data = vif.rd_data;
        end

        if(trans_captured) begin
          `uvm_info("MON", tr.convert2string(), UVM_HIGH);
          send.write(tr);
        end
       
       `uvm_info("MON", $sformatf("wr_counter : %0d", wr_counter), UVM_DEBUG);
       `uvm_info("MON", $sformatf("wr_completed_counter : %0d", wr_completed_counter), UVM_DEBUG);
        
        if(wr_completed_counter == 15) begin
          wr_complete_ev.trigger();
          `uvm_info("MON", $sformatf("ev_wr_complete triggered as all write Requests are completed : %0d", wr_counter), UVM_MEDIUM);
          wr_completed_counter = 0;
        end
        
     end
  endtask

endclass