`timescale 1ns / 1ps

module uart_tx_core
  import uart_core_pkg::*;
  (
  input  logic        clk_i,
  input  logic        reset_i,

  input  logic [31:0] config_i,

  output logic        ready_o,
  input  logic        valid_i,
  input  logic [7:0]  data_i,

  output logic        tx_o
  );

  ////////// Signal Declarations //////////

  // TODO: clearly explain all these signals
  data_width_e  config_data_width;
  parity_en_e   config_parity_en;
  parity_type_e config_parity_type;
  stop_e        config_stop;
  logic [26:0]  config_baud_div;
  logic [26:0]  config_baud_max;

  // Internal
  logic [2:0]  config_data_msb;

  always_comb begin
    config_data_width  = data_width_e'(config_i[1:0]);
    config_parity_en   = parity_en_e'(config_i[2]);
    config_parity_type = parity_type_e'(config_i[3]);
    config_stop        = stop_e'(config_i[4]);
    config_baud_max    = config_i[31:5] - 1;

    case (config_data_width)
      DW_5: config_data_msb = 3'd4;
      DW_6: config_data_msb = 3'd5;
      DW_7: config_data_msb = 3'd6;
      DW_8: config_data_msb = 3'd7;
      default: config_data_msb = 3'd7;
    endcase
  end

  logic [7:0]  shift_reg;
  logic        parity_reg;
  logic [26:0] baud_count;
  logic [3:0]  bit_count;

  tx_state_e tx_state;

  initial ready_o = 1'b0;
  initial tx_o = 1'b1;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      ready_o    <= 1'b0;
      tx_o       <= 1'b1;
      tx_state   <= IDLE;
      shift_reg  <= '0;
      parity_reg <= 1'b0;
      baud_count <= '0;
      bit_count  <= '0;
    end else begin

      case (tx_state)
        IDLE: begin
          // outputs
          ready_o <= 1'b1;
          tx_o    <= 1'b1;

          if (ready_o && valid_i) begin
            tx_state     <= START;
            shift_reg    <= data_i;
            baud_count <= '0;
          end
        end

        START: begin
          // outputs
          ready_o <= 1'b0;
          tx_o    <= 1'b0;

          if (baud_count == config_baud_max) begin
            tx_state <= DATA;
            parity_reg <= !config_parity_type; // TODO: Explain
            baud_count <= '0;
            bit_count <= '0;
          end else begin
            baud_count <= baud_count + 1;
          end
        end

        DATA: begin
          tx_o <= shift_reg[0];

          if (baud_count == config_baud_max) begin
            // shift operation
            shift_reg <= {1'b1, shift_reg[7:1]};

            // parity operation
            if (config_parity_en) begin
              parity_reg <= parity_reg ^ shift_reg[0];
            end

            // transition state
            if (bit_count == config_data_msb) begin
              tx_state <= (config_parity_en) ? PARITY : STOP;
              baud_count <= '0;
            end else begin
              bit_count <= bit_count + 1;
              baud_count <= '0;
            end

          end else begin
            baud_count <= baud_count + 1;
          end

        end

        PARITY: begin
          tx_o <= parity_reg;

          if (baud_count == config_baud_max) begin
            tx_state <= STOP;
            baud_count <= '0;
          end else begin
            baud_count <= baud_count + 1;
          end
        end

        STOP: begin
          tx_o <= 1'b1;

          if (baud_count == config_baud_max) begin
            tx_state <= (config_stop == TWO_STOP) ? EXTRA_STOP : IDLE;
            baud_count <= '0;
          end else begin
            baud_count <= baud_count + 1;
          end
        end

        EXTRA_STOP: begin
          tx_o <= 1'b1;

          if (baud_count == config_baud_max) begin
            tx_state <= IDLE;
            baud_count <= '0;
          end else begin
            baud_count <= baud_count + 1;
          end
        end

        default: begin
          // TODO: more can be done with this?
          tx_state <= IDLE;
        end

      endcase
    end
  end


endmodule
