------------------------------------------------------------------------------
-- Title      : Cameralink Interface
-- Project    : zcu102_mlabs
------------------------------------------------------------------------------
-- File        : cameralink_interface.vhd
-- Author      : Daniel Jiménez Mazure
-- Company     : DDR/TICH
-- Created     : 16/06/2018 - 15:07:29
-- Last update : 17/10/2019 - 18:37:12
-- Synthesizer : Vivado 2017.4
-- FPGA        : MPSoC Ultrascale +
------------------------------------------------------------------------------
-- Description: Cameralink Interface using IDDR
------------------------------------------------------------------------------
-- Copyright (c) 2018 DDR/TICH
------------------------------------------------------------------------------
-- Revisions  :
-- Date/Time                Version               Engineer
-- 16/06/2018 - 15:07:29      1.0             dasjimaz@gmail.com
-- Description :
-- Created
------------------------------------------------------------------------------
-- SVN Commit : $Date: 2018-07-27 15:23:56 +0200 (vi., 27 jul. 2018) $
------------------------------------------------------------------------------
------------------------------------------------------------------------------
--* @cambio 16/06/2018 djmazure => versión inicial
------------------------------------------------------------------------------
-- Descripción:
-- Instancia de PLL + CameralinkRX  que toma como reloj de entrada el de
-- un transmisor tipo cameralink. Debe mapear las salidas según lo especificado en
-- el DS del sensor.
-- El controlador debe considerar dos opciones: que el reloj de cameralink sea
-- mayor o menor a 50MHz. El VCO del PLL debe quedar en un rango entre 800MHz y
-- 1600 MHz, por lo que los factores de multiplicación y división deben adaptarse
-- a la frecuencia de entrada para no salirse del rango de dicho VCO.
-- La primera opción para deserializar los datos es usar ISERDES, con el problema 
-- inicial que los ISERDES 3 para ULTRASCALE PLUS no tienen ni bitslip ni un factor
-- de 1:7 para cameralink.
-- La segunda opción es registrar los datos con IDDRs. Para alinear los datos con 
-- el reloj 7:4, el reloj se puede deserializar. Para poder darle el mismo reloj
-- tanto al deserializador como al PLL se puede usar un IBUFDS_DIFF_OUT (salida 
-- diferencial) y usar cada una de las dos salidas para rutal al PLL y al de-
-- serializador. La invertida al DDR y la normal al PLL. 
------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_MISC.all;
use IEEE.NUMERIC_STD.all;
--use IEEE.MATH_REAL.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity cameralink_interface is
  generic(
    G_INVERTED_POLARITY : integer := 0
    );
  port (
    RST            : in  std_logic;
    CAMLINK_XCLK_P : in  std_logic;
    CAMLINK_XCLK_N : in  std_logic;
    CAMLINK_X_P    : in  std_logic_vector(3 downto 0);
    CAMLINK_X_N    : in  std_logic_vector(3 downto 0);
    CAMLINK_CC_P   : out std_logic_vector(4 downto 1);
    CAMLINK_CC_N   : out std_logic_vector(4 downto 1);
    CAMLINK_TFG_P  : in  std_logic;     -- To Frame Graber
    CAMLINK_TFG_N  : in  std_logic;
    CAMLINK_TC_P   : out std_logic;     -- To Camera
    CAMLINK_TC_N   : out std_logic;
    --
    AV             : out std_logic;
    HBLANK         : out std_logic;
    VBLANK         : out std_logic;
    DATA_OUT       : out std_logic_vector(15 downto 0);
    CLK_OUT        : out std_logic;     -- synced with data
    --
    UART_TX        : in  std_logic;     -- Processor controlled uart
    UART_RX        : out std_logic
    );
end cameralink_interface;


architecture behavioral of cameralink_interface is

  -----------------------------------------------------------------------------
  -- Constantes
  -----------------------------------------------------------------------------


  -----------------------------------------------------------------------------
  -- Componentes
  -----------------------------------------------------------------------------

  -- Cameralink deserializer core

  component cameralink_receiver is
    generic(
      G_INVERTED_POLARITY : integer := 0
      );
    port (
      X_DATA_IN    : in  std_logic_vector(3 downto 0);
      FPGA_IN_DATA : out std_logic_vector(27 downto 0);
      CLK_7X       : in  std_logic;
      CLK_7X_180   : in  std_logic;
      CLK_1X       : in  std_logic;
      LOCKED       : in  std_logic;
      CLK_CL_DATA  : in  std_logic;
      CLK_DATA_BUS : out std_logic_vector(7 downto 0);
      LED_OUT      : out std_logic_vector(3 downto 0)
      );
  end component cameralink_receiver;


  component cameralink_clocking is
    port (
      RST            : in  std_logic;
      CLK_CAMERALINK : in  std_logic;
      CLK_7X         : out std_logic;
      CLK_1X         : out std_logic;
      CLK_7X_180     : out std_logic;
      PS_REQ         : in  std_logic;
      PS_DONE        : out std_logic;
      LOCKED         : out std_logic
      );
  end component cameralink_clocking;


  component cameralink_calibration is
    port (
      CLK          : in  std_logic;
      CLK_7X       : in  std_logic;
      LOCKED       : in  std_logic;
      CLK_DATA_BUS : in  std_logic_vector(7 downto 0);
      PS_DONE      : in  std_logic;
      SHIFT_CLK    : out std_logic
      );
  end component cameralink_calibration;
  ------------------------------------------------------------------------------
  -- SIGNALS
  ------------------------------------------------------------------------------
  -- Señales

  signal clk_1x              : std_logic;
  signal clk_7x              : std_logic;
  signal clk_7x_180          : std_logic;
  signal clk_cameralink      : std_logic;
  signal locked              : std_logic;
  signal clk_cameralink_data : std_logic;
  -- Salidas
  signal r_pxdata            : std_logic_vector(23 downto 0) := (others => '0');
  signal data_in_to_device   : std_logic_vector(27 downto 0);
  signal r_data_in_to_device : std_logic_vector(27 downto 0) := (others => '0');

  -- signal r_led_out              : std_logic_vector(3 downto 0)                      := (others => '0');
  signal s_led_out              : std_logic_vector(3 downto 0);
  signal r_cc_out               : std_logic_vector(4 downto 1) := (others => '0');
  --
  signal r_fmc_hpc0_camlink_led : std_logic_vector(3 downto 0) := "0001";
  signal r_clk_125_cnt          : unsigned(26 downto 0)        := (others => '0');
  signal s_clk_data_bus         : std_logic_vector(7 downto 0);
  --
  signal s_camlink_tfg          : std_logic;
  signal s_camlink_tc           : std_logic;
  --
  signal r_camlink_tfg          : std_logic                    := '0';
  signal r_camlink_tc           : std_logic                    := '0';
  -- 
  signal s_x_data               : std_logic_vector(3 downto 0);
  --
  signal r_fval                 : std_logic                    := '0';
  signal r_lval                 : std_logic                    := '0';
  signal r_dval                 : std_logic                    := '0';
  --
  signal r_red                  : std_logic_vector(7 downto 0) := (others => '0');
  signal r_green                : std_logic_vector(7 downto 0) := (others => '0');
  signal r_blue                 : std_logic_vector(7 downto 0) := (others => '0');
  --
  signal r_pixel_cnt            : unsigned(23 downto 0)        := (others => '0');
  signal r_line_cnt             : unsigned(15 downto 0)        := (others => '0');
  signal r_re_lval              : std_logic_vector(1 downto 0) := (others => '0');
  signal r_re_fval              : std_logic_vector(1 downto 0) := (others => '0');
  --
  signal s_rst_cal              : std_logic;
  signal s_ps_done              : std_logic;

  -----------------------------------------------------------------------------
  -- Atributos (ILA)
  -----------------------------------------------------------------------------
  attribute keep                      : string;
  attribute mark_debug                : string;
  attribute keep of r_pixel_cnt       : signal is "true";
  attribute mark_Debug of r_pixel_cnt : signal is "true";
  attribute keep of r_line_cnt        : signal is "true";
  attribute mark_Debug of r_line_cnt  : signal is "true";
  attribute keep of r_fval            : signal is "true";
  attribute mark_Debug of r_fval      : signal is "true";
  attribute keep of r_lval            : signal is "true";
  attribute mark_Debug of r_lval      : signal is "true";
  attribute keep of r_dval            : signal is "true";
  attribute mark_Debug of r_dval      : signal is "true";
  attribute keep of r_red             : signal is "true";
  attribute mark_Debug of r_red       : signal is "true";
  attribute keep of r_green           : signal is "true";
  attribute mark_Debug of r_green     : signal is "true";
  attribute keep of r_blue            : signal is "true";
  attribute mark_Debug of r_blue      : signal is "true";

begin



  inst_IBUFDS_XCLK : IBUFDS_DIFF_OUT
    generic map (
      DQS_BIAS => "FALSE"               -- (FALSE, TRUE)
      )
    port map (
      O  => clk_cameralink,             -- 1-bit output: Buffer diff_p output
      OB => clk_cameralink_data,        -- 1-bit output: Buffer diff_n output
      I  => CAMLINK_XCLK_P,  -- 1-bit input: Diff_p buffer input (connect directly to top-level port)
      IB => CAMLINK_XCLK_N  -- 1-bit input: Diff_n buffer input (connect directly to top-level port)
      );


  generate_ibufds_data : for i in 0 to 3 generate
    isnt_IBUFDS_XDATA : IBUFDS
      generic map (
        DQS_BIAS => "FALSE"             -- (FALSE, TRUE)
        )
      port map (
        O  => s_x_data(i),              -- 1-bit output: Buffer output
        I  => CAMLINK_X_P(i),  -- 1-bit input: Diff_p buffer input (connect directly to top-level port)
        IB => CAMLINK_X_N(i)  -- 1-bit input: Diff_n buffer input (connect directly to top-level port)
        );
  end generate;

  isnt_IBUFDS_TFG : IBUFDS
    generic map (
      DQS_BIAS => "FALSE"               -- (FALSE, TRUE)
      )
    port map (
      O  => s_camlink_tfg,              -- 1-bit output: Buffer output
      I  => CAMLINK_TFG_P,  -- 1-bit input: Diff_p buffer input (connect directly to top-level port)
      IB => CAMLINK_TFG_N  -- 1-bit input: Diff_n buffer input (connect directly to top-level port)
      );

  Inst_cameralink_clocking : cameralink_clocking
    port map (
      RST            => RST,
      CLK_CAMERALINK => clk_cameralink,
      CLK_7X         => clk_7x,
      CLK_1X         => clk_1x,
      CLK_7X_180     => clk_7x_180,     -- 7x 180 degrees   
      PS_REQ         => s_rst_cal,
      PS_DONE        => s_ps_done,
      LOCKED         => locked
      );

  -----------------------------------------------------------------------------
  -- Cameralink Receiver
  -----------------------------------------------------------------------------

  Inst_cameralink_receiver : cameralink_receiver
    generic map (
      G_INVERTED_POLARITY => 0          -- should be a 4 bit mask
      )
    port map(
      X_DATA_IN    => s_x_data,         -- filtered by P/N inversion
      FPGA_IN_DATA => data_in_to_device,
      CLK_7X       => clk_7x,
      CLK_7X_180   => clk_7x_180,
      CLK_1X       => clk_1x,
      LOCKED       => locked,
      CLK_CL_DATA  => clk_cameralink_data,
      CLK_DATA_BUS => s_clk_data_bus,
      LED_OUT      => s_led_out
      );
  -----------------------------------------------------------------------------
  -- Cameralink Calibration
  -----------------------------------------------------------------------------
  Inst_cameralink_calibration : cameralink_calibration
    port map (
      CLK          => clk_1x,
      CLK_7X       => clk_7x,
      LOCKED       => locked,
      CLK_DATA_BUS => s_clk_data_bus,
      PS_DONE      => s_ps_done,
      SHIFT_CLK    => s_rst_cal
      );


  -----------------------------------------------------------------------------
  -- Data extraction
  -----------------------------------------------------------------------------

  PX_DATA_EXTRACTION : process(clk_1x)
  begin
    if (rising_edge(clk_1x)) then
      --
      r_data_in_to_device <= data_in_to_device;

      r_dval     <= r_data_in_to_device(20);
      r_fval     <= r_data_in_to_device(19);
      r_lval     <= r_data_in_to_device(18);
      --
      r_blue(7)  <= r_data_in_to_device(26);
      r_blue(6)  <= r_data_in_to_device(25);
      r_blue(5)  <= r_data_in_to_device(17);
      r_blue(4)  <= r_data_in_to_device(16);
      r_blue(3)  <= r_data_in_to_device(15);
      r_blue(2)  <= r_data_in_to_device(14);
      r_blue(1)  <= r_data_in_to_device(13);
      r_blue(0)  <= r_data_in_to_device(12);
      -- r_green es equivalente a tap 1
      r_green(7) <= r_data_in_to_device(24);
      r_green(6) <= r_data_in_to_device(23);
      r_green(5) <= r_data_in_to_device(11);
      r_green(4) <= r_data_in_to_device(10);
      r_green(3) <= r_data_in_to_device(9);
      r_green(2) <= r_data_in_to_device(8);
      r_green(1) <= r_data_in_to_device(7);
      r_green(0) <= r_data_in_to_device(6);
      -- r_red es equivalente a tap 0
      r_red(7)   <= r_data_in_to_device(22);
      r_red(6)   <= r_data_in_to_device(21);
      r_red(5)   <= r_data_in_to_device(5);
      r_red(4)   <= r_data_in_to_device(4);
      r_red(3)   <= r_data_in_to_device(3);
      r_red(2)   <= r_data_in_to_device(2);
      r_red(1)   <= r_data_in_to_device(1);
      r_red(0)   <= r_data_in_to_device(0);
      --
      r_cc_out   <= (others => '1');

    --
    end if;
  end process;

  process(clk_1x)
  begin
    if rising_edge(clk_1x) then
      r_re_lval <= r_re_lval(0) & r_lval;
      r_re_fval <= r_re_fval(0) & r_fval;
      if r_re_lval = "01" then
        r_line_cnt <= r_line_cnt + 1;
      end if;
      if r_fval = '0' then
        r_line_cnt <= (others => '0');
      end if;
      --
      if r_fval = '1' then
        if r_lval = '1' then
          if r_dval = '1' then
            r_pixel_cnt <= r_pixel_cnt + 1;
          end if;  -- dval
        end if;  -- lval
      else
        r_pixel_cnt <= (others => '0');
      end if;  -- fval
    end if;
  end process;

  process(clk_1x)                       -- HeartBeat
  begin
    if rising_edge(clk_1x) then
      if r_re_fval = "01" then
        r_clk_125_cnt <= r_clk_125_cnt + 1;
        if r_clk_125_cnt = 8 then
          r_fmc_hpc0_camlink_led <= r_fmc_hpc0_camlink_led(2 downto 0) & r_fmc_hpc0_camlink_led(3);
          r_clk_125_cnt          <= (others => '0');
        end if;
      end if;
    end if;
  end process;


  -----------------------------------------------------
  --- Salidas
  -----------------------------------------------------

  inst_OBUFDS_TC : OBUFDS
    port map (
      O  => CAMLINK_TC_P,  -- 1-bit output: Diff_p output (connect directly to top-level port)
      OB => CAMLINK_TC_N,  -- 1-bit output: Diff_n output (connect directly to top-level port)
      I  => s_camlink_tc                -- 1-bit input: Buffer input
      );

  generate_obufds_cc : for i in 1 to 4 generate
    inst_OBUFDS_CC : OBUFDS
      port map (
        O  => CAMLINK_CC_P(i),  -- 1-bit output: Diff_p output (connect directly to top-level port)
        OB => CAMLINK_CC_N(i),  -- 1-bit output: Diff_n output (connect directly to top-level port)
        I  => r_cc_out(i)               -- 1-bit input: Buffer input
        );
  end generate;


  DATA_OUT(15 downto 8) <= r_green;     -- coloco el tap0 en el verde AXIS
  DATA_OUT(7 downto 0)  <= r_red;       -- coloco el tap0 en el azul AXIS

  -- Colocar el mismo nivel en los 3 colores genera escala de grises

  AV <= r_dval;

  --

  HBLANK  <= not r_lval;
  VBLANK  <= not r_fval;
  CLK_OUT <= clk_1x;



  -----------------------------------------------------------------------------
  -- TO ZYNQ PROCESSOR UART
  -----------------------------------------------------------------------------

  process(s_camlink_tfg, UART_TX)
  begin
    if G_INVERTED_POLARITY = 0 then
      UART_RX      <= s_camlink_tfg;
      s_camlink_tc <= UART_TX;  -- Entrada desde la PS para transmitirlo hacia el sensor
    else
      UART_RX      <= not s_camlink_tfg;
      s_camlink_tc <= not UART_TX;  -- Entrada desde la PS para transmitirlo hacia el sensor
    end if;

  end process;



end behavioral;
