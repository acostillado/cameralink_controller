------------------------------------------------------------------------------
-- Title      : Cameralink Clocking
-- Project    : zzcu102_mpsoc
------------------------------------------------------------------------------
-- File        : cameralink_clocking.vhd
-- Author      : Daniel Jim�nez Mazure
-- Company     : DDR/TICH
-- Created     : 16/06/2018 - 15:07:29
-- Last update : 17/10/2019 - 12:34:56
-- Synthesizer : Vivado 2017.4
-- FPGA        : MPSoC Ultrascale +
------------------------------------------------------------------------------
-- Description: Cameralink Clocking using a MMCME2 PLL ADV
------------------------------------------------------------------------------
-- Copyright (c) 2018 DDR/TICH
------------------------------------------------------------------------------
-- Revisions  :
-- Date/Time                Version               Engineer
-- 16/06/2018 - 15:07:29      1.0             dasjimaz@gmail.com
-- Description :
-- Created
------------------------------------------------------------------------------
-- SVN Commit : $Date: 2018-07-25 15:15:30 +0200 (mi., 25 jul. 2018) $
------------------------------------------------------------------------------
------------------------------------------------------------------------------
--* @cambio 28/06/2018 djmazure => versi�n inicial
------------------------------------------------------------------------------
-- Descripci�n:
-- Instancia de PLL  (Xilinx) que toma como reloj de entrada el de
-- un transmisor tipo cameralink.
--
------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_MISC.all;
use IEEE.NUMERIC_STD.all;
use IEEE.MATH_REAL.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity cameralink_clocking is
  port (
    RST            : in  std_logic;
    CLK_CAMERALINK : in  std_logic;
    CLK_7X         : out std_logic;
    CLK_7X_180     : out std_logic;
    CLK_1X         : out std_logic;
    PS_REQ         : in  std_logic;
    PS_DONE        : out std_logic;
    LOCKED         : out std_logic
    
    );
end cameralink_clocking;


architecture rtl of cameralink_clocking is
  -----------------------------------------------------------------------------
  -- Constantes
  -----------------------------------------------------------------------------
  constant C_CAMERALINK_CLK_FREQ_MHZ : integer := 80;
  constant C_PLL_MULTIPLIER          : real    := real(14);
  constant C_PLL_DIVIDER             : integer := integer(C_PLL_MULTIPLIER/3.5);
  constant C_PLL_DIVIDER_2           : integer := 8;
  constant C_CAMERALINK_PERIOD       : real    := (real(1000)/ real(C_CAMERALINK_CLK_FREQ_MHZ));
  constant C_MAX_SHIFT_BEFORE_RESET  : integer := 250;
  ------------------------------------------------------------------------------
  -- SIGNAL DEFINITIONS
  ------------------------------------------------------------------------------

  signal clk_in_pll                       : std_logic;
  signal clk_fb                           : std_logic;
  signal clk_fb_bufg                      : std_logic;
  signal clk_out0, clk_out1               : std_logic;
  signal clk_out2                         : std_logic;
  signal locked_int                       : std_logic;
  --
  signal clk_1x_obufg                     : std_logic;
  signal r_psen                           : std_logic            := '0';
  signal r_psincdec                       : std_logic            := '0';
  signal psdone                           : std_logic;
  signal r_flag_ps_req                    : std_logic            := '0';
  signal r_shift_counter                  : unsigned(5 downto 0) := (others => '0');
  signal r_mmcm_rst                       : std_logic            := '0';
  --
  -----------------------------------------------------------------------------
  -- Atributos (ILA)
  -----------------------------------------------------------------------------
  attribute keep                          : string;
  attribute mark_debug                    : string;
  attribute keep of r_psincdec            : signal is "true";
  attribute mark_Debug of r_psincdec      : signal is "true";
  attribute keep of r_flag_ps_req         : signal is "true";
  attribute mark_Debug of r_flag_ps_req   : signal is "true";
  attribute keep of r_psen                : signal is "true";
  attribute mark_Debug of r_psen          : signal is "true";
  attribute keep of r_mmcm_rst            : signal is "true";
  attribute mark_Debug of r_mmcm_rst      : signal is "true";
  attribute keep of r_shift_counter       : signal is "true";
  attribute mark_Debug of r_shift_counter : signal is "true";

begin

  Inst_XCLK_BUFG : BUFG
    port map(
      O => clk_in_pll,
      I => CLK_CAMERALINK
      );

  -- PLL
  Inst_pll : MMCME2_ADV
    generic map(
      BANDWIDTH            => "HIGH",
      COMPENSATION         => "ZHOLD",
      STARTUP_WAIT         => false,
      DIVCLK_DIVIDE        => 1,
      CLKFBOUT_MULT_F      => C_PLL_MULTIPLIER,
      CLKFBOUT_PHASE       => 0.000,
      CLKFBOUT_USE_FINE_PS => false,
      CLKOUT0_DIVIDE_F     => C_PLL_MULTIPLIER,
      CLKOUT0_PHASE        => 0.000,
      CLKOUT0_DUTY_CYCLE   => 0.500,
      CLKOUT0_USE_FINE_PS  => false,
      CLKOUT1_DIVIDE       => C_PLL_DIVIDER,  -- 2 for 560MHz and i serdes, 4 for DDR and 280 MHz
      CLKOUT1_PHASE        => 0.000,
      CLKOUT1_DUTY_CYCLE   => 0.500,
      CLKOUT1_USE_FINE_PS  => true,
      CLKOUT2_DIVIDE       => C_PLL_DIVIDER,  -- 3.5x clock to use de IDDR technique to deserialize the d
      CLKOUT2_PHASE        => 180.000,
      CLKOUT2_DUTY_CYCLE   => 0.500,
      CLKOUT2_USE_FINE_PS  => false,
      CLKIN1_PERIOD        => C_CAMERALINK_PERIOD
      )
    port map(
      CLKFBOUT     => clk_fb,
      CLKFBOUTB    => open,
      CLKOUT0      => clk_out0,                             -- 40MHz
      CLKOUT0B     => open,
      CLKOUT1      => clk_out1,                             -- 280MHz
      CLKOUT1B     => open,
      CLKOUT2      => clk_out2,                             -- 148, MHz
      CLKOUT2B     => open,
      CLKOUT3      => open,
      CLKOUT3B     => open,
      CLKOUT4      => open,
      CLKOUT5      => open,
      CLKFBIN      => clk_fb_bufg,
      CLKIN1       => clk_in_pll,
      CLKIN2       => '0',
      CLKINSEL     => '1',
      DADDR        => (others => '0'),
      DCLK         => '0',
      DEN          => '0',
      DI           => (others => '0'),
      DO           => open,
      DRDY         => open,
      DWE          => '0',
      PSCLK        => clk_1x_obufg,
      PSEN         => r_psen,
      PSINCDEC     => r_psincdec,
      PSDONE       => psdone,
      LOCKED       => locked_int,
      CLKINSTOPPED => open,
      CLKFBSTOPPED => open,
      PWRDWN       => '0',
      RST          => r_mmcm_rst
      );

  Inst_bufg_clk : BUFG
    port map(
      O => clk_fb_bufg,
      I => clk_fb
      );

  Inst_clkout0_buf : BUFG
    port map(
      O => clk_1x_obufg,
      I => clk_out0
      );

  Inst_clkout1_buf : BUFG
    port map(
      O => CLK_7X,
      I => clk_out1
      );

  Inst_clkout2_buf : BUFG
    port map(
      O => CLK_7X_180,
      I => clk_out2
      );

  -----------------------------------------------------------------------------
  -- Fine Phase Shift Requested
  -----------------------------------------------------------------------------
  process(clk_1x_obufg, locked_int)
  begin
    if locked_int = '0' then
      r_flag_ps_req <= '0';
      r_mmcm_rst    <= '0';
    else
      if rising_edge(clk_1x_obufg) then
        r_mmcm_rst <= RST;
        r_psen     <= '0';
        r_psincdec <= '0';
        if psdone = '1' then
          r_flag_ps_req   <= '0';
          r_shift_counter <= r_shift_counter + 1;
          if r_shift_counter = C_MAX_SHIFT_BEFORE_RESET then
            r_mmcm_rst      <= '1';
            r_shift_counter <= (others => '0');
          end if;
        elsif PS_REQ = '1' and r_flag_ps_req = '0' then
          r_flag_ps_req <= '1';
          r_psincdec    <= '1';
          r_psen        <= '1';
        end if;
      end if;
    end if;
  end process;


  CLK_1X  <= clk_1x_obufg;
  LOCKED  <= locked_int;
  PS_DONE <= psdone;

end architecture rtl;




