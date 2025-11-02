`timescale 1ns/1ps

module tb_fifo1;
  localparam int DSIZE = 8;
  localparam int ASIZE = 4;   // DEPTH = 16

  // ------------------------------------------------------------
  // Asynchronous clocks
  // ------------------------------------------------------------
  logic wclk=0, rclk=0;
  always #5  wclk = ~wclk;   // 100 MHz
  always #7  rclk = ~rclk;   // ~71 MHz

  // ------------------------------------------------------------
  // Resets (active-low)
  // ------------------------------------------------------------
  logic wrst_n, rrst_n;
  initial begin
    wrst_n = 1'b0; rrst_n = 1'b0;
    #100;                   // keep in reset for 100 ns
    wrst_n = 1'b1; rrst_n = 1'b1;
  end

  // ------------------------------------------------------------
  // DUT I/O
  // ------------------------------------------------------------
  logic [DSIZE-1:0] wdata, rdata;
  logic winc, rinc;
  logic wfull, rempty;

  // ------------------------------------------------------------
  // DUT instance (your fifo1)
  // ------------------------------------------------------------
  fifo #(.DSIZE(DSIZE), .ASIZE(ASIZE)) dut (
    .wclk   (wclk),
    .wrst_n (wrst_n),
    .winc   (winc),
    .wdata  (wdata),
    .wfull  (wfull),

    .rclk   (rclk),
    .rrst_n (rrst_n),
    .rinc   (rinc),
    .rdata  (rdata),
    .rempty (rempty)
  );

  // ------------------------------------------------------------
  // Compact VCD for EPWave
  // ------------------------------------------------------------
  initial begin
    $dumpfile("fifo1_tb.vcd");
    $dumpvars(0, tb_fifo1.wclk, tb_fifo1.rclk, tb_fifo1.wrst_n, tb_fifo1.rrst_n);
    $dumpvars(0, tb_fifo1.winc, tb_fifo1.wdata, tb_fifo1.wfull);
    $dumpvars(0, tb_fifo1.rinc, tb_fifo1.rdata, tb_fifo1.rempty);
  end

  // Print only on real accept (at the clock edge)
  always @(posedge wclk) if (winc && !wfull)  $strobe("[%0t] WRITE  0x%0h", $time, wdata);
  always @(posedge rclk) if (rinc && !rempty) $strobe("[%0t] READ   0x%0h", $time, rdata);

  // ------------------------------------------------------------
  // Pre-edge helpers (negedge)
  // Rationale:
  //  - Decide using the flag value *before* the next posedge.
  //  - Keep winc/rinc asserted across the posedge where we know
  //    the operation will be accepted.
  //  - This avoids off-by-one when FULL/EMPTY change on the same
  //    posedge that accepts the last write/read.
  // ------------------------------------------------------------
  integer next_w;  // next data to write

  task automatic write_one_preedge();
    // Hold winc=1 across a posedge where we already know !wfull
    begin
      @(negedge wclk);            // flags are stable until next posedge
      wait (wrst_n && !wfull);    // guarantee acceptance on the next posedge
      wdata = next_w[DSIZE-1:0];
      winc  = 1'b1;
      @(posedge wclk);            // acceptance here (winc=1 && !wfull pre-edge)
      @(negedge wclk);            // deassert after the accepting posedge
      winc  = 1'b0;
      next_w++;
    end
  endtask

  task automatic read_one_preedge();
    begin
      @(negedge rclk);
      wait (rrst_n && !rempty);   // will be accepted on the next posedge
      rinc = 1'b1;
      @(posedge rclk);            // acceptance here
      @(negedge rclk);
      rinc = 1'b0;
    end
  endtask

  task automatic fill_to_full_preedge();
    begin
      while (1) begin
        @(negedge wclk);
        if (!wrst_n) continue;
        if (wfull) break;
        wdata = next_w[DSIZE-1:0];
        winc  = 1'b1;
        @(posedge wclk);
        @(negedge wclk);
        winc  = 1'b0;
        next_w++;
      end
    end
  endtask

  initial begin
    winc = 1'b0; rinc = 1'b0; wdata = '0; next_w = 0;

    #120;
    for (int i=0;i<16;i++) write_one_preedge();
    for (int i=0;i<16;i++) read_one_preedge();
    fill_to_full_preedge();
    for (int i=0;i<8;i++) read_one_preedge();
    fill_to_full_preedge();
    for (int i=0;i<8;i++) read_one_preedge();
    fill_to_full_preedge();
    for (int i=0;i<8;i++) read_one_preedge();
    
    repeat (4) @(posedge wclk);
    $finish;
  end

  // Simple watchdog
  initial begin
    #20_000; $fatal(1, "[TB] TIMEOUT");
  end
endmodule
