`ifndef AXI_LITE_ITEM_SV
`define AXI_LITE_ITEM_SV

class axi_lite_item extends uvm_sequence_item;
    rand axi_lite_cmd_e       cmd;
    rand bit [AXI_ADDR_WIDTH-1:0] addr;
    rand bit [AXI_DATA_WIDTH-1:0] data;
    rand bit [AXI_DATA_WIDTH/8-1:0] wstrb;

    bit [AXI_DATA_WIDTH-1:0] rdata;
    bit [1:0]                resp;

    constraint c_wstrb {
        wstrb dist {4'h0 := 1, 4'h1 := 2, 4'h2 := 2, 4'h4 := 2, 4'h8 := 2,
                    4'h3 := 2, 4'h5 := 1, 4'hA := 1, 4'hC := 2, 4'hF := 8};
    }

    constraint c_addr_mix {
        addr dist {
            [8'h00:8'h0F] := 70,
            [8'h10:8'h1F] := 15,
            [8'h20:8'hFF] := 15
        };
    }

    `uvm_object_utils_begin(axi_lite_item)
        `uvm_field_enum(axi_lite_cmd_e, cmd, UVM_DEFAULT)
        `uvm_field_int(addr,  UVM_HEX)
        `uvm_field_int(data,  UVM_HEX)
        `uvm_field_int(wstrb, UVM_HEX)
        `uvm_field_int(rdata, UVM_HEX)
        `uvm_field_int(resp,  UVM_BIN)
    `uvm_object_utils_end

    function new(string name = "axi_lite_item");
        super.new(name);
    endfunction

    function bit is_aligned();
        return addr[1:0] == 2'b00;
    endfunction

    function bit is_in_range();
        return (addr >> 2) < AXI_REG_COUNT;
    endfunction

    function bit is_legal_addr();
        return is_aligned() && is_in_range();
    endfunction

    function axi_lite_addr_kind_e addr_kind();
        if (!is_aligned()) begin
            return ADDR_UNALIGNED;
        end
        if (!is_in_range()) begin
            return ADDR_OUT_OF_RANGE;
        end
        return ADDR_LEGAL;
    endfunction
endclass

`endif
