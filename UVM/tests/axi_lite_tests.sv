`ifndef AXI_LITE_TESTS_SV
`define AXI_LITE_TESTS_SV

class axi_lite_base_test extends uvm_test;
    `uvm_component_utils(axi_lite_base_test)

    axi_lite_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = axi_lite_env::type_id::create("env", this);
    endfunction

    task run_selected_sequence(uvm_phase phase, axi_lite_base_sequence seq);
        phase.raise_objection(this);
        seq.start(env.agent.sequencer);
        repeat (10) @(posedge env.agent.driver.vif.aclk);
        phase.drop_objection(this);
    endtask
endclass

class axi_lite_smoke_test extends axi_lite_base_test;
    `uvm_component_utils(axi_lite_smoke_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        axi_lite_smoke_sequence seq = axi_lite_smoke_sequence::type_id::create("seq");
        run_selected_sequence(phase, seq);
    endtask
endclass

class axi_lite_random_test extends axi_lite_base_test;
    `uvm_component_utils(axi_lite_random_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        axi_lite_random_sequence seq = axi_lite_random_sequence::type_id::create("seq");
        run_selected_sequence(phase, seq);
    endtask
endclass

class axi_lite_wstrb_test extends axi_lite_base_test;
    `uvm_component_utils(axi_lite_wstrb_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        axi_lite_wstrb_sequence seq = axi_lite_wstrb_sequence::type_id::create("seq");
        run_selected_sequence(phase, seq);
    endtask
endclass

class axi_lite_error_test extends axi_lite_base_test;
    `uvm_component_utils(axi_lite_error_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        axi_lite_error_sequence seq = axi_lite_error_sequence::type_id::create("seq");
        run_selected_sequence(phase, seq);
    endtask
endclass

class axi_lite_backpressure_test extends axi_lite_base_test;
    `uvm_component_utils(axi_lite_backpressure_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_config_db#(int unsigned)::set(this, "env.agent.driver", "max_ready_delay", 8);
    endfunction

    task run_phase(uvm_phase phase);
        axi_lite_backpressure_sequence seq = axi_lite_backpressure_sequence::type_id::create("seq");
        run_selected_sequence(phase, seq);
    endtask
endclass

`endif
