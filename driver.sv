
class drv extends uvm_driver#(transaction);
  `uvm_component_utils(drv)

  transaction tr;
  virtual dut_if vif;

  typedef enum logic [1:0] {IDLE=0, DELAY=1, CMD=2} state_t;
  state_t state;

  function new(input string path = "drv", uvm_component parent = null);
    super.new(path,parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual dut_if)::get(this,"","vif",vif)) `uvm_error("drv","Unable to access Interface");
  endfunction

  virtual task run_phase(uvm_phase phase);
    reset_dut();
    master_fsm();
  endtask

  // Reset task
  task reset_dut();
    repeat(2) @(posedge vif.clk);
    `uvm_info("DRV","Asserting reset",UVM_NONE);
    vif.rst     <= 1;
    vif.wr_valid <= 0;
    vif.wr_data <= '0;
    vif.wr_addr <= '0;
    vif.awid <= '0;
    vif.rd_valid <= 0;
    vif.rd_addr <= '0;
    vif.arid <= '0;
    repeat(5) @(posedge vif.clk);
    vif.rst <= 0;
    repeat(3) @(posedge vif.clk);
    state <= IDLE;
    `uvm_info("DRV","Reset complete",UVM_NONE);
  endtask

  // Master FSM
  task master_fsm();
    forever begin
      @(posedge vif.clk);
      case(state)
        IDLE: begin
          vif.wr_valid <= 0;
          vif.wr_data <= '0;
          vif.wr_addr <= '0;
          vif.awid <= '0;
          vif.rd_valid <= 0;
          vif.rd_addr <= '0;
          vif.arid <= '0;

          seq_item_port.get_next_item(tr);
          state <= DELAY;
        end

        DELAY: begin
          repeat(tr.delay) @(posedge vif.clk);
          state <= CMD;
        end

        CMD: begin
          if(tr.op == WRITE) begin
            vif.wr_valid <= 1;
            vif.wr_data <= tr.wr_data;
            vif.wr_addr <= tr.wr_addr;
            vif.awid <= tr.awid;
            wait(vif.wr_rdy);
          end else if(tr.op == READ) begin
            vif.rd_valid <= 1;
            vif.rd_addr <= tr.rd_addr;
            vif.arid <= tr.arid;
            wait(vif.rd_rdy);
          end else if(tr.op == READ_WRITE) begin
            wait(vif.wr_rdy && vif.rd_rdy);
            vif.wr_valid <= 1;
            vif.wr_data <= tr.wr_data;
            vif.wr_addr <= tr.wr_addr;
            vif.awid <= tr.awid;

            vif.rd_valid <= 1;
            vif.rd_addr <= tr.rd_addr;
            vif.arid <= tr.arid;
          end
          state <= IDLE;
          `uvm_info("DRV", tr.convert2string(), UVM_HIGH);
          seq_item_port.item_done();
        end
      endcase
    end
  endtask

endclass
