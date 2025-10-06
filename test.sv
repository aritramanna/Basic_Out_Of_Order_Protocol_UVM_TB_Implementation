class test extends uvm_test;
`uvm_component_utils(test)
 
function new(input string inst = "test", uvm_component c);
super.new(inst,c);
endfunction
 
env e;
generator gen;
wr_rd_sequence_random_id wr_rd_seq;
 
virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);
  e   = env::type_id::create("env",this);
  set_type_override_by_type(generator::get_type(), wr_rd_sequence_random_id::get_type());
  gen = generator::type_id::create("gen");
endfunction
 
virtual task run_phase(uvm_phase phase);
  phase.raise_objection(this);
  gen.start(e.a.seqr);
  phase.drop_objection(this);
  
  // Drain time helps caputre pending response data
  phase.phase_done.set_drain_time(this,500ns);
endtask
endclass
