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
        env.agent.driver.wait_for_idle();
        repeat (2) @(env.agent.driver.vif.mon_cb);
        if (env.agent.driver.submitted != env.scoreboard.checked_transfers)
            `uvm_error("COUNT", "submitted and checked transfer counts differ")
        `uvm_info("TEST_DONE", "all requests drained and checked", UVM_LOW)
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

class axi_lite_learning_test extends axi_lite_base_test;
    `uvm_component_utils(axi_lite_learning_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        axi_lite_learning_sequence seq =
            axi_lite_learning_sequence::type_id::create("seq");
        run_selected_sequence(phase, seq);
    endtask
endclass



class axi_lite_v11_test extends axi_lite_base_test;
    `uvm_component_utils(axi_lite_v11_test)
    int profile=1;
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
        uvm_config_db#(bit)::set(this,"env.agent.driver","pipeline_mode",1);
        super.build_phase(phase);
    endfunction
    task run_phase(uvm_phase phase);
        axi_lite_v11_sequence seq=axi_lite_v11_sequence::type_id::create("seq");
        seq.profile=profile;
        run_selected_sequence(phase,seq);
    endtask
    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        env.agent.monitor.require_scenarios(profile);
    endfunction
endclass
class axi_lite_slave_backpressure_test extends axi_lite_v11_test;
    `uvm_component_utils(axi_lite_slave_backpressure_test)
    function new(string name,uvm_component parent); super.new(name,parent); profile=1; endfunction
endclass
class axi_lite_concurrent_test extends axi_lite_v11_test;
    `uvm_component_utils(axi_lite_concurrent_test)
    function new(string name,uvm_component parent); super.new(name,parent); profile=2; endfunction
endclass
class axi_lite_continuous_test extends axi_lite_v11_test;
    `uvm_component_utils(axi_lite_continuous_test)
    function new(string name,uvm_component parent); super.new(name,parent); profile=3; endfunction
endclass
`endif
