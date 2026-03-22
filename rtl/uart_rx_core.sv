`timescale 1ns / 1ps

module uart_rx_core
  import uart_core_pkg::*;
  (
  input logic clk_i,
  input logic reset_i,
  input logic [31:0] config_i,

  // NOTE: rx_i must be synchronized to clk_i, use a
  // synchronizer & feed the output as rx_i.
  input logic rx_i,

  output logic [7:0] data_o,
  output logic valid_o,
  output logic frame_error_o,
  output logic parity_error_o
  );

  ////////// Signal Declarations //////////

  // TODO: clearly explain all these signals
  data_width_e  config_data_width;
  parity_en_e   config_parity_en;
  parity_type_e config_parity_type;
  stop_e        config_stop;
  logic [26:0]  config_baud_max;

  // Internal
  logic [2:0] config_data_msb;

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

    data_o = shift_reg;
  end

  logic [7:0]  shift_reg;
  logic        parity_reg;
  logic [26:0] baud_count;
  logic [3:0]  sample_count;
  logic [3:0]  bit_count;

  uart_state_e rx_state;

  logic negedge_rx;
  detect_negedge negedge_detector(
    .clk_i(clk_i),
    .reset_i(reset_i),
    .sig_i(rx_i),
    .negedge_o(negedge_rx)
  );

  initial valid_o = 1'b0;
  initial frame_error_o = 1'b0;
  initial parity_error_o = 1'b0;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      valid_o <= 1'b0;
      frame_error_o <= 1'b0;
      parity_error_o <= 1'b0;

      rx_state <= IDLE;
      shift_reg <= '0;
      parity_reg <= 1'b0;
      baud_count <= '0;
      sample_count <= '0;
      bit_count <= '0;
    end else begin
      case(rx_state)
        IDLE: begin
          valid_o <= 1'b0;
          frame_error_o <= 1'b0;
          parity_error_o <= 1'b0;

          // detected a beginning of START bit
          if (negedge_rx) begin
            rx_state <= START;
            baud_count <= '0;
            sample_count <= '0;
            shift_reg <= '0;
          end
        end
        START: begin
          baud_count <= baud_count + 1;

          if(baud_count == config_baud_max) begin
            sample_count <= sample_count + 1;
            baud_count <= '0;

            if (rx_i) begin
              // False start
              rx_state <= IDLE;
            end else if (sample_count == 4'd7) begin
              // Successfully detected a good start bit
              // AKA 8 consecutive LOW samples.

              rx_state <= DATA;
              baud_count <= '0;
              sample_count <= '0;
              bit_count <= '0;

              parity_reg <= !config_parity_type; // TODO: Explain
            end
          end

        end
        DATA: begin
          baud_count <= baud_count + 1;

          if (baud_count == config_baud_max) begin
            sample_count <= sample_count + 1;
            baud_count <= '0;

            // Middle of bit period
            if (sample_count == 4'd15) begin
              bit_count <= bit_count + 1;
              sample_count <= '0;

              // shift operation
              case (config_data_width)
                DW_5: shift_reg <= {3'b000, rx_i, shift_reg[4:1]};
                DW_6: shift_reg <= {2'b00, rx_i, shift_reg[5:1]};
                DW_7: shift_reg <= {1'b0, rx_i, shift_reg[6:1]};
                DW_8: shift_reg <= {rx_i, shift_reg[7:1]};
              endcase

              // calculate parity
              if (config_parity_en) begin
                parity_reg <= parity_reg ^ rx_i;
              end

              if (bit_count == config_data_msb) begin
                rx_state <= config_parity_en ? PARITY : STOP;
                baud_count <= '0;
                sample_count <= '0;
                bit_count <= '0;
              end
            end
          end

        end
        PARITY: begin
          baud_count <= baud_count + 1;

          if (baud_count == config_baud_max) begin
            sample_count <= sample_count + 1;
            baud_count <= '0;

            if (sample_count == 4'd15) begin
              rx_state <= STOP;
              baud_count <= '0;
              sample_count <= '0;

              // Parity error detected
              parity_error_o <= parity_reg != rx_i;
            end
          end
        end
        STOP: begin
          baud_count <= baud_count + 1;

          if (baud_count == config_baud_max) begin
            sample_count <= sample_count + 1;
            baud_count <= '0;

            if (sample_count == 4'd15) begin
              bit_count <= bit_count + 1;
              sample_count <= '0;

              // Frame error detected
              frame_error_o <= frame_error_o || (rx_i != 1'b1);

              if(bit_count == config_stop) begin
                // Assert valid_o for a single pulse
                valid_o <= 1'b1;

                // Transition
                rx_state <= IDLE;
                baud_count <= '0;
                sample_count <= '0;
                bit_count <= '0;
              end
            end
          end
        end

        default: begin
          // Can do more?
          rx_state <= IDLE;
        end
      endcase

    end
  end

endmodule
