package uart_tx_pkg;

  typedef enum logic [3:0] {
    IDLE,
    START,
    DATA,
    PARITY,
    STOP,
    EXTRA_STOP
  } tx_state_e;

  typedef enum logic [2:0] {
    SEL_IDLE,
    SEL_START,
    SEL_DATA,
    SEL_PARITY,
    SEL_STOP
  } tx_sel_e;

endpackage : uart_tx_pkg
