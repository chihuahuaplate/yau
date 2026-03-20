package uart_core_pkg;

  typedef enum logic [1:0] {
    DW_5 = 2'b00,
    DW_6,
    DW_7,
    DW_8
  } data_width_e;

  typedef enum logic {
    DISABLED = 1'b0,
    ENABLED
  } parity_en_e;

  typedef enum logic {
    ODD = 1'b0,
    EVEN
  } parity_type_e;

  typedef enum logic {
    ONE_STOP = 1'b0,
    TWO_STOP
  } stop_e;

  typedef enum logic [3:0] {
    IDLE,
    START,
    DATA,
    PARITY,
    STOP
  } uart_state_e;

endpackage : uart_core_pkg
