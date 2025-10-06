class generator extends uvm_sequence#(transaction);
 `uvm_object_utils(generator)

 transaction tr;

 function new(input string name = "generator");
   super.new(name);
 endfunction

 virtual task body();
   repeat(15) begin
      tr = transaction::type_id::create("tr");
      start_item(tr);
     assert(tr.randomize() with {req_valid == 1;});
     `uvm_info("SEQ", tr.convert2string(), UVM_HIGH);
      finish_item(tr);
   end
 endtask

endclass