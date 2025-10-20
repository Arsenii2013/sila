
module ls_spiTB();

    localparam unsigned  DATA_W      = 32;
    localparam unsigned  SPI_W       = 1;
    localparam unsigned  PRESCALER   = 1000;
    localparam unsigned  FRONT       = "rise";
    localparam string    ALWAYS_SCK  = "no";
    typedef logic [DATA_W-1: 0] data_t;

    logic clk;
    logic reset;

    logic SCK;
    logic MISO;
    logic MOSI;

    data_t master_tx_data;
    data_t master_rx_data;
    data_t slave_tx_data;
    data_t slave_rx_data;


    logic  master_load = 0;
    logic  master_empty;
    logic  master_full;
    logic  slave_load = 0;
    logic  slave_empty;
    logic  slave_full;


    sys_clk_gen
    #(
        .halfcycle (4000),
        .offset    (0)
    ) APP_CLK_GEN (
        .sys_clk (clk)
    );

    ls_spi_master #(
        .DATA_W(DATA_W),
        .SPI_W(SPI_W),
        .PRESCALER(PRESCALER),
        .FRONT(FRONT),
        .ALWAYS_SCK(ALWAYS_SCK)
    ) DUT_master (
        .clk(clk),
        .reset(reset),

        .tx_data(master_tx_data),
        .rx_data(master_rx_data),
        .tx_load(master_load),
        .tx_empty(master_empty),
        .rx_full(master_full),

        .SCK(SCK),
        .MISO(MISO),
        .MOSI(MOSI)
    );

    ls_spi_slave #(
        .DATA_W(DATA_W),
        .SPI_W(SPI_W),
        .FRONT(FRONT)
    ) DUT_slave (
        .clk(clk),
        .reset(reset),

        .tx_data(slave_tx_data),
        .rx_data(slave_rx_data),
        .tx_load(slave_load),
        .tx_empty(slave_empty),
        .rx_full(slave_full),

        .SCK(SCK),
        .MISO(MISO),
        .MOSI(MOSI)
    );

    ls_spi_checker  #(
        .DATA_W(DATA_W),
        .SPI_W(SPI_W),
        .PRESCALER(PRESCALER),
        .FRONT(FRONT),
        .ALWAYS_SCK(ALWAYS_SCK)
    ) check (
        .clk(clk),
        .reset(reset),

        .master_tx_data(master_tx_data),
        .master_rx_data(master_rx_data),
        .slave_tx_data(slave_tx_data),
        .slave_rx_data(slave_rx_data),
        .master_load(master_load),
        .master_empty(master_empty),
        .master_full(master_full),
        .slave_full(slave_full),
        .slave_load(slave_load),
        .slave_empty(slave_empty),

        .SCK(SCK),
        .MISO(MISO),
        .MOSI(MOSI)
    );

    initial begin
        rst();
        @(posedge clk);
        RandomTest();
        BurstRandomTest();
        #100ns;
        $stop();
    end

    task RandomTest();
        for(int i = 0; i < 1000; i ++) begin
            repeat ($urandom_range(1000, 10)) @(posedge clk);
            do_transaction($random, $random);
        end
    endtask

    task BurstRandomTest();
        for(int i = 0; i < 31; i ++) begin
            for(int j = 0; j < 31; j ++) begin
                do_transaction($random, $random);
            end
            repeat ($urandom_range(10000, 1000)) @(posedge clk);
        end
    endtask

    task load_slave(data_t data);
        @(posedge clk);
        slave_tx_data <= data;
        slave_load <= 1;
        @(posedge clk);
        slave_load <= 0;
        @(posedge clk);
    endtask

    task wait_slave();
        wait(slave_empty && slave_full == 1);
        @(posedge clk);
    endtask

    task load_master_and_start_transaction(data_t data);
        @(posedge clk);
        master_tx_data <= data;
        master_load <= 1;
        @(posedge clk);
        master_load <= 0;
        @(posedge clk);
    endtask

    task wait_master();
        wait(master_empty && master_full == 1);
        @(posedge clk);
    endtask

    task do_transaction(data_t master_data, data_t slave_data);
        fork
        begin
            load_slave(slave_data);
            @(posedge clk);
            wait_slave();
        end
        begin
            load_master_and_start_transaction(master_data);
            @(posedge clk);
            wait_master();
        end
        join
    endtask

    task rst();
        reset <= 1;
        repeat (10) @(posedge clk);
        reset <= 0;
        @(posedge clk);
    endtask

endmodule