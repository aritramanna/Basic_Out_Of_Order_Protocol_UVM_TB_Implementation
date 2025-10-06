typedef enum {WRITE, READ, READ_WRITE} op_type;

typedef enum {WR_RESP, RD_RESP, RD_WR_RESP} rsp_type;

class transaction extends uvm_sequence_item;

  // Randomizable fields
  rand int      delay;   // Random delay
  rand op_type  op;      // READ / WRITE / READ_WRITE operation
  rand rsp_type op_rsp;  // Resp Type RD / WR
  rand logic req_valid;       // Any Request Valid
  logic rsp_valid;       // Any Response Valid

  // Write channel 
  rand logic        wr_valid;
  rand logic [7:0]  wr_data;
  rand logic [7:0]  wr_addr;
  rand logic [3:0]  awid;
       logic        wr_rdy;

  // Write response 
       logic        wr_resp_valid;
       logic [3:0]  wr_resp_id;
       logic [1:0]  wr_resp;

  // Read channel 
  rand logic        rd_valid;
  rand logic [7:0]  rd_addr;
  rand logic [3:0]  arid;
       logic        rd_rdy;

  // Read response
       logic        rd_resp_valid;
       logic [3:0]  rd_resp_id;
       logic [1:0]  rd_resp;
       logic [7:0]  rd_data;

  `uvm_object_utils_begin(transaction)
    `uvm_field_int (delay,         UVM_ALL_ON)
    `uvm_field_enum(op_type, op,   UVM_ALL_ON)

    // Write channel
    `uvm_field_int (wr_valid,      UVM_ALL_ON)
    `uvm_field_int (wr_data,       UVM_ALL_ON)
    `uvm_field_int (wr_addr,       UVM_ALL_ON)
    `uvm_field_int (awid,          UVM_ALL_ON)
    `uvm_field_int (wr_rdy,        UVM_ALL_ON)

    // Write response
    `uvm_field_int (wr_resp_valid, UVM_ALL_ON)
    `uvm_field_int (wr_resp_id,    UVM_ALL_ON)
    `uvm_field_int (wr_resp,       UVM_ALL_ON)

    // Read channel
    `uvm_field_int (rd_valid,      UVM_ALL_ON)
    `uvm_field_int (rd_addr,       UVM_ALL_ON)
    `uvm_field_int (arid,          UVM_ALL_ON)
    `uvm_field_int (rd_rdy,        UVM_ALL_ON)

    // Read response
    `uvm_field_int (rd_resp_valid, UVM_ALL_ON)
    `uvm_field_int (rd_resp_id,    UVM_ALL_ON)
    `uvm_field_int (rd_resp,       UVM_ALL_ON)
    `uvm_field_int (rd_data,       UVM_ALL_ON)
  `uvm_object_utils_end

  // Constructor
  function new(string name = "transaction");
    super.new(name);
    this.rsp_valid = 0;
    this.req_valid = 0;
  endfunction

  // Constraints
  constraint delay_c { delay inside {[0:5]}; }

  constraint type_c {
    (op == WRITE)      -> (wr_valid == 1);
    (op == READ)       -> (rd_valid == 1);
    (op == READ_WRITE) -> (wr_valid == 1 && rd_valid == 1);
  }
  
  constraint wr_data_c { wr_data != 8'h00; }

  // Convert transaction to string (op-dependent)
  function string convert2string();
    string s;

    if(req_valid) begin
      
     s = $sformatf("[op=%s] ", op.name());
      
     case (op)

      WRITE: begin
        s = {s, $sformatf("  WRITE : wr_valid=%0b wr_data=0x%0h wr_addr=0x%0h awid=%0d", wr_valid, wr_data, wr_addr, awid)};
      end

      READ: begin
        s = {s, $sformatf("  READ  : rd_valid=%0b rd_addr=0x%0h arid=%0d", rd_valid, rd_addr, arid)};
      end

      READ_WRITE: begin
        s = {s, $sformatf("  WRITE : wr_valid=%0b wr_data=0x%0h wr_addr=0x%0h awid=%0d ||", wr_valid, wr_data, wr_addr, awid)};
        s = {s, $sformatf(" READ : rd_valid=%0b rd_addr=0x%0h arid=%0d", rd_valid, rd_addr, arid)};
      end

     endcase
    end

    if(rsp_valid) begin
      case (op_rsp)
        WR_RESP: s = {s, $sformatf(" || WR_RESP : wr_resp_valid=%0b wr_resp_id=%0d wr_resp=0x%0h", wr_resp_valid, wr_resp_id, wr_resp)};
        RD_RESP: s = {s, $sformatf(" || RD_RESP : rd_resp_valid=%0b rd_resp_id=%0d rd_resp=0x%0h rd_data=0x%0h", rd_resp_valid, rd_resp_id, rd_resp, rd_data)};
        RD_WR_RESP: s = {s, $sformatf(" || WR_RESP : wr_resp_valid=%0b wr_resp_id=%0d wr_resp=0x%0h || RD_RESP : rd_resp_valid=%0b rd_resp_id=%0d rd_resp=0x%0h rd_data=0x%0h", 
                          wr_resp_valid, wr_resp_id, wr_resp, rd_resp_valid, rd_resp_id, rd_resp, rd_data)};
      endcase
    end

    return s;
  endfunction

endclass
