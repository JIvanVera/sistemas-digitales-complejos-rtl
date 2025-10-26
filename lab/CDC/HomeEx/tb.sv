`timescale 1ns/1ps

module valid_ready_tb;

  // Parameters
  localparam W = 32;

  // Domain A signals
  reg              i_a_clk;
  reg              i_a_reset_n;
  reg              i_a_valid;
  wire             o_a_ready;
  reg  [W-1:0]     i_a_data;

  // Domain B signals
  reg              i_b_clk;
  reg              i_b_reset_n;
  wire             o_b_valid;
  reg              i_b_ready;
  wire [W-1:0]     o_b_data;

  // DUT
  valid_ready_cdc #(.W(W)) dut (
    .i_a_clk(i_a_clk),
    .i_a_reset_n(i_a_reset_n),
    .i_a_valid(i_a_valid),
    .o_a_ready(o_a_ready),
    .i_a_data(i_a_data),

    .i_b_clk(i_b_clk),
    .i_b_reset_n(i_b_reset_n),
    .o_b_valid(o_b_valid),
    .i_b_ready(i_b_ready),
    .o_b_data(o_b_data)
  );

  // Clock generation
  initial i_a_clk = 0;
  always #5  i_a_clk = ~i_a_clk;   // 100 MHz

  initial i_b_clk = 0;
  always #7  i_b_clk = ~i_b_clk;   // ~71 MHz (asynchronous)

  // VCD dump for waveform view
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, valid_ready_tb);
  end

  // Scoreboard and counters
  reg [W-1:0] sent_queue [0:255];
  integer sent_count = 0;
  integer recv_count = 0;
  integer error_count = 0;

  // Main stimulus
  initial begin
    i_a_reset_n = 0;
    i_b_reset_n = 0;
    i_a_valid   = 0;
    i_a_data    = 0;
    i_b_ready   = 0;

    #30;
    i_a_reset_n = 1;
    i_b_reset_n = 1;
    #40;

    fork
      send_data_sequence();
      b_ready_behavior();
    join_any

    #500;
    print_summary();
    $finish;
  end

  // Send a sequence of data from A
  task send_data_sequence;
    integer i;
    begin
      for (i = 0; i < 12; i = i + 1) begin
        send_data(32'hA100_0000 + i);
        #(20 + {$random} % 60);
      end
    end
  endtask

  // Send one data word
  task send_data(input [W-1:0] data);
    begin
      @(posedge i_a_clk);
      while (!o_a_ready) @(posedge i_a_clk);
      i_a_data  <= data;
      i_a_valid <= 1;
      @(posedge i_a_clk);
      i_a_valid <= 0;
      sent_queue[sent_count] = data;
      sent_count = sent_count + 1;
      $display("[%0t] Sent data: 0x%08X", $time, data);
    end
  endtask

  // Random ready behavior for domain B
  task b_ready_behavior;
    begin
      forever begin
        i_b_ready = 1;
        repeat (3 + {$random} % 8) @(posedge i_b_clk);
        i_b_ready = 0;
        repeat (2 + {$random} % 5) @(posedge i_b_clk);
      end
    end
  endtask

  // Check received data
  always @(posedge i_b_clk) begin
    if (o_b_valid && i_b_ready) begin
      $display("[%0t] Received data: 0x%08X", $time, o_b_data);

      if (recv_count < sent_count) begin
        if (o_b_data !== sent_queue[recv_count]) begin
          $display("ERROR: Expected 0x%08X, got 0x%08X",
                   sent_queue[recv_count], o_b_data);
          error_count = error_count + 1;
        end else begin
          $display("OK: Received expected value 0x%08X", o_b_data);
        end
      end else begin
        $display("WARNING: Extra data received (no match in queue)");
        error_count = error_count + 1;
      end
      recv_count = recv_count + 1;
    end
  end

  // Summary report
  task print_summary;
    begin
      $display("\n====================================");
      $display("Sent count      = %0d", sent_count);
      $display("Received count  = %0d", recv_count);
      $display("Error count     = %0d", error_count);
      if (error_count == 0 && recv_count == sent_count)
        $display("TEST PASSED");
      else
        $display("TEST FAILED");
      $display("====================================\n");
    end
  endtask

endmodule
