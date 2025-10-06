class sco extends uvm_scoreboard;
  `uvm_component_utils(sco)
 
  uvm_tlm_analysis_fifo#(transaction) mon_data; // tlm fifo for collecting monitor data
  transaction tr;
  virtual dut_if vif;

  typedef struct packed {
    logic [7:0] wr_data;
    logic [7:0] wr_addr;
    logic       valid;
  } t_wr;

  typedef struct packed {
    logic [7:0] rd_addr;
    logic [7:0] rd_data;
    logic       valid;
  } t_rd;

  // reference memory model
  logic [7:0] mem_ref [0:255]; 

  // per-ID unbounded pending queues for rd and wr channels
  t_wr wr_pend_arr [0:15] [$];
  t_rd rd_pend_arr [0:15] [$];

  t_wr wr_entry;
  t_rd rd_entry;
  
  logic wr_arr_err_flag = 0;
  logic rd_arr_err_flag = 0;
 
  function new(input string inst = "sco", uvm_component parent = null);
    super.new(inst,parent);
  endfunction
    
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    //tr = transaction::type_id::create("tr");
    mon_data = new("mon_data", this);
    if(!uvm_config_db#(virtual dut_if)::get(this,"","vif",vif))
    `uvm_error("ref_model","Unable to access Interface");
  endfunction
    
  virtual task run_phase(uvm_phase phase);

    mem_init(); // initialize ref memory to zero

    wait(!vif.rst);
    
    `uvm_info("SCO", "Scoreboard Started....", UVM_LOW);

    forever begin
      
      mon_data.get(tr);
      `uvm_info("SCO", $sformatf("[->Monitor Data Received] %0s", tr.convert2string()), UVM_HIGH);

      // Enqueue requests into pending queues based on ID

      if (tr.req_valid) begin
        case(tr.op)

          WRITE : begin
            if (wr_pend_arr[tr.awid].size() < 8) begin
              wr_pend_arr[tr.awid].push_back('{wr_data: tr.wr_data, wr_addr: tr.wr_addr, valid: 1'b1});
              `uvm_info("SCO", $sformatf("  [WR_REQ] ID=%0d Addr=0x%0h Data=0x%0h Pending_WR_Entries=%0d", tr.awid, tr.wr_addr, tr.wr_data, wr_pend_arr[tr.awid].size()), UVM_HIGH);
            end else begin
              `uvm_info("SCO", $sformatf("  [WR_REQ] ID=%0d Addr=0x%0h Data=0x%0h - Pending WR Queue Full!", tr.awid, tr.wr_addr, tr.wr_data), UVM_HIGH);
            end
          end

          READ : begin
            if (rd_pend_arr[tr.arid].size() < 8) begin
              rd_pend_arr[tr.arid].push_back('{rd_addr: tr.rd_addr, rd_data: 8'h00, valid: 1'b1});
              `uvm_info("SCO", $sformatf("  [RD_REQ] ID=%0d Addr=0x%0h Pending_RD_Entries=%0d", tr.arid, tr.rd_addr, rd_pend_arr[tr.arid].size()), UVM_HIGH);
            end else begin
              `uvm_info("SCO", $sformatf("  [RD_REQ] ID=%0d Addr=0x%0h - Pending RD Queue Full!", tr.arid, tr.rd_addr), UVM_HIGH);
            end
          end

          READ_WRITE : begin
            // Handle Write Part
            if (wr_pend_arr[tr.awid].size() < 8) begin
              wr_pend_arr[tr.awid].push_back('{wr_data: tr.wr_data, wr_addr: tr.wr_addr, valid: 1'b1});
              `uvm_info("SCO", $sformatf("  [WR_REQ] ID=%0d Addr=0x%0h Data=0x%0h Pending_WR_Entries=%0d", tr.awid, tr.wr_addr, tr.wr_data, wr_pend_arr[tr.awid].size()), UVM_HIGH);
            end else begin
              `uvm_info("SCO", $sformatf("  [WR_REQ] ID=%0d Addr=0x%0h Data=0x%0h - Pending WR Queue Full!", tr.awid, tr.wr_addr, tr.wr_data), UVM_HIGH);
            end

            // Handle Read Part
            if (rd_pend_arr[tr.arid].size() < 8) begin
              rd_pend_arr[tr.arid].push_back('{rd_addr: tr.rd_addr, rd_data: 8'h00, valid: 1'b1});
              `uvm_info("SCO", $sformatf("  [RD_REQ] ID=%0d Addr=0x%0h Pending_RD_Entries=%0d", tr.arid, tr.rd_addr, rd_pend_arr[tr.arid].size()), UVM_HIGH);
            end else begin
              `uvm_info("SCO", $sformatf("  [RD_REQ] ID=%0d Addr=0x%0h - Pending RD Queue Full!", tr.arid, tr.rd_addr), UVM_HIGH);
            end

          end

        endcase

      end // if req_valid

      // Process Responses

      if (tr.rsp_valid) begin
        case(tr.op_rsp)

          WR_RESP : begin
            if (wr_pend_arr[tr.wr_resp_id].size() > 0) begin
              wr_entry = wr_pend_arr[tr.wr_resp_id].pop_front();
              mem_ref[wr_entry.wr_addr] = wr_entry.wr_data;
              `uvm_info("SCO", $sformatf("  [WR_RESP] ID=%0d Addr=0x%0h Data=0x%0h - Write Completed. Pending_WR_Entries=%0d", tr.wr_resp_id, wr_entry.wr_addr, wr_entry.wr_data, wr_pend_arr[tr.wr_resp_id].size()), UVM_HIGH);
            end else begin
              `uvm_info("SCO", $sformatf("  [WR_RESP] ID=%0d - No Pending Write Requests!", tr.wr_resp_id), UVM_HIGH);
            end
          end

          RD_RESP : begin
            if (rd_pend_arr[tr.rd_resp_id].size() > 0) begin
              rd_entry = rd_pend_arr[tr.rd_resp_id].pop_front();
              rd_entry.rd_data = mem_ref[rd_entry.rd_addr];
              `uvm_info("SCO", $sformatf("  [RD_RESP] ID=%0d Addr=0x%0h Data=0x%0h - Read Completed. Pending_RD_Entries=%0d", tr.rd_resp_id, rd_entry.rd_addr, rd_entry.rd_data, rd_pend_arr[tr.rd_resp_id].size()), UVM_HIGH);
            end else begin
              `uvm_info("SCO", $sformatf("  [RD_RESP] ID=%0d - No Pending Read Requests!", tr.rd_resp_id), UVM_HIGH);
            end

            if(rd_entry.rd_data != tr.rd_data) begin
              `uvm_error("SCO", $sformatf("  [FAIL][RD_RESP] ID=%0d Addr=0x%0h - Data Mismatch! Expected=0x%0h Received=0x%0h", tr.rd_resp_id, rd_entry.rd_addr, rd_entry.rd_data, tr.rd_data));
            end else begin
              `uvm_info("SCO", $sformatf("  [PASS][RD_RESP] ID=%0d Addr=0x%0h - Data Match! Data=0x%0h", tr.rd_resp_id, rd_entry.rd_addr, tr.rd_data), UVM_LOW);
            end
          end

          RD_WR_RESP : begin
            // Handle Write Response Part
            if (wr_pend_arr[tr.wr_resp_id].size() > 0) begin
              wr_entry = wr_pend_arr[tr.wr_resp_id].pop_front();
              mem_ref[wr_entry.wr_addr] = wr_entry.wr_data;
              `uvm_info("SCO", $sformatf("  [WR_RESP] ID=%0d Addr=0x%0h Data=0x%0h - Write Completed. Pending_WR_Entries=%0d", tr.wr_resp_id, wr_entry.wr_addr, wr_entry.wr_data, wr_pend_arr[tr.wr_resp_id].size()), UVM_HIGH);
            end else begin
              `uvm_info("SCO", $sformatf("  [WR_RESP] ID=%0d - No Pending Write Requests!", tr.wr_resp_id), UVM_HIGH);
            end

            // Handle Read Response Part
            if (rd_pend_arr[tr.rd_resp_id].size() > 0) begin
              rd_entry = rd_pend_arr[tr.rd_resp_id].pop_front();
              rd_entry.rd_data = mem_ref[rd_entry.rd_addr];
              `uvm_info("SCO", $sformatf("  [RD_RESP] ID=%0d Addr=0x%0h Data=0x%0h - Read Completed. Pending_RD_Entries=%0d", tr.rd_resp_id, rd_entry.rd_addr, rd_entry.rd_data, rd_pend_arr[tr.rd_resp_id].size()), UVM_HIGH);
            end else begin
              `uvm_info("SCO", $sformatf("  [RD_RESP] ID=%0d - No Pending Read Requests!", tr.rd_resp_id), UVM_HIGH);
            end

            if(rd_entry.rd_data != tr.rd_data) begin
              `uvm_error("SCO", $sformatf("  [FAIL][RD_RESP] ID=%0d Addr=0x%0h - Data Mismatch! Expected=0x%0h Received=0x%0h", tr.rd_resp_id, rd_entry.rd_addr, rd_entry.rd_data, tr.rd_data));
            end else begin
              `uvm_info("SCO", $sformatf("  [PASS][RD_RESP] ID=%0d Addr=0x%0h - Data Match! Data=0x%0h", tr.rd_resp_id, rd_entry.rd_addr, tr.rd_data), UVM_LOW);
            end

          end
        endcase
      end // if rsp_valid

    end

  endtask 

  // Function: extract_phase - checks leftover transactions in the pending FIFOs
   virtual function void extract_phase(uvm_phase phase);
      super.extract_phase(phase);

      wr_arr_err_flag = 0;
      rd_arr_err_flag = 0;

     `uvm_info("SCO", $sformatf("Beginning Extract Phase Checks......."), UVM_LOW);

     // check for pending items in tlm fifo
      if (mon_data.try_get(tr)) begin
         `uvm_error( "mon_data_tlm_fifo", 
                     { "found leftover transaction(s) : ", tr.convert2string() } );
      end else `uvm_info("SCO", $sformatf("  [PASS] All transactions in mon_data tlm_fifo has been processed"), UVM_LOW);

      // check for pending items in wr fifo
      foreach(wr_pend_arr[i])begin
        if(wr_pend_arr[i].size() != 0) begin
          `uvm_error("wr_pend_arr", {"found leftover transaction(s) : awid - ", $sformatf(i)});
          wr_arr_err_flag = 1;
        end
      end

     if (!wr_arr_err_flag) `uvm_info("SCO", $sformatf("  [PASS] All transactions in wr_pend_arr has been processed"), UVM_LOW);

      // check for pending items in rd fifo
      foreach(rd_pend_arr[i])begin
        if(rd_pend_arr[i].size() != 0) begin
          `uvm_error("rd_pend_arr", {"found leftover transaction(s) : arid - ", $sformatf(i)});
          rd_arr_err_flag = 1;
        end
      end

     if (!rd_arr_err_flag) `uvm_info("SCO", $sformatf("  [PASS] All transactions in rd_pend_arr has been processed"), UVM_LOW);

      // Ref Memory Dump
     `uvm_info("SCO", $sformatf("Reference Memory Dump:"), UVM_HIGH);

      foreach(mem_ref[i]) begin
        if(mem_ref[i] != 8'h00)
          `uvm_info("SCO", $sformatf("  Addr=0x%0h Data=0x%0h", i, mem_ref[i]), UVM_HIGH);
      end

   endfunction: extract_phase 

  // Memory Initialization Task
  task mem_init;
    wait(vif.rst);
    @(posedge vif.clk);
    for (int i = 0; i < 256; i++) begin
      mem_ref[i] = 8'h00;
    end
  endtask
 
endclass