class wr_rd_sequence_random_id extends generator;
 `uvm_object_utils(wr_rd_sequence_random_id)

 uvm_event wr_complete_ev; // wr complete event

 logic [7:0] wr_addr_queue[$];

 function new(input string name = "wr_rd_sequence_random_id");
   super.new(name);
 endfunction

 virtual task body();
   wr_complete_ev = uvm_event_pool::get_global("ev_wr_complete");
   // first send the writes
   repeat(15) begin
      tr = transaction::type_id::create("tr");
      start_item(tr);
      assert(tr.randomize() with {req_valid == 1; (op == WRITE);});
      wr_addr_queue.push_back(tr.wr_addr);
      `uvm_info("SEQ", tr.convert2string(), UVM_HIGH);
      finish_item(tr);
   end

   `uvm_info("SEQ", "All WRITES sent, now wait for their completions", UVM_LOW);

   wr_complete_ev.wait_trigger;

  `uvm_info("SEQ", "All WRITES completed, now send READS", UVM_LOW);

    // now send the reads to the completed writes
    foreach (wr_addr_queue[i]) begin
        tr = transaction::type_id::create("tr");
        start_item(tr);
        assert(tr.randomize() with {req_valid == 1; (op == READ); (rd_addr == wr_addr_queue[i]);});
        `uvm_info("SEQ", tr.convert2string(), UVM_HIGH);
        finish_item(tr);
    end
 endtask
 
endclass