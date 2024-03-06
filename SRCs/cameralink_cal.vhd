------------------------------------------------------------------------------
-- Title      : Cameralink Calibration
-- Project    : zcu102_mlabs
------------------------------------------------------------------------------
-- File        : cameralink_calibration.vhd
-- Author      : Daniel Jiménez Mazure
-- Company     : DDR/TICH
-- Created     : 15/02/2019 - 15:47:29
-- Last update : 15/02/2019 - 15:47:29
-- Synthesizer : Vivado 2018.1
-- FPGA        : MPSoC Ultrascale +
------------------------------------------------------------------------------
-- Description: Cameralink Interface using IDDR
------------------------------------------------------------------------------
-- Copyright (c) 2018 DDR/TICH
------------------------------------------------------------------------------
-- Revisions  :
-- Date/Time                Version               Engineer
-- 15/02/2019 - 15:47:29      1.0             dasjimaz@gmail.com
-- Description :
-- Created
------------------------------------------------------------------------------
-- SVN Commit : $Date: 2019-02-15 15:53:56 +0200 (vi., 15 feb. 2019) $
------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_MISC.all;
use IEEE.NUMERIC_STD.all;
--use IEEE.MATH_REAL.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity cameralink_calibration is
  port (
    CLK          : in  std_logic;
    CLK_7X       : in  std_logic;
    LOCKED       : in  std_logic;
    CLK_DATA_BUS : in  std_logic_vector(7 downto 0);
    PS_DONE      : in  std_logic;
    SHIFT_CLK    : out std_logic
    );
end cameralink_calibration;

architecture RTL of cameralink_calibration is

  -----------------------------------------------------------------------------
  -- Constants
  -----------------------------------------------------------------------------
  constant C_TIMEOUT_WIDTH : integer := 5;
  constant C_TIMEOUT       : integer := 2**C_TIMEOUT_WIDTH-1;
  --
  constant C_OOL_WIDTH     : integer := 8;
  constant C_OOL_MAX       : integer := 2**C_OOL_WIDTH-1;


  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------

  signal r_shift_clk       : std_logic                            := '0';
  signal r_cal_timeout     : unsigned(C_TIMEOUT_WIDTH-1 downto 0) := (others => '0');
  signal r_wait_ps_done    : std_logic                            := '0';
  --
  signal r_flag_error      : std_logic                            := '0';
  signal r_flag_error_cdc  : std_logic_vector(2 downto 0)         := (others => '0');
  signal r_flag_error_vec  : std_logic_vector(5 downto 0)         := (others => '0');
  signal r_flag_error_long : std_logic                            := '0';
  --
  signal r_out_of_locked   : std_logic                            := '1';
  signal r_ool_cnt         : unsigned(C_OOL_WIDTH-1 downto 0)     := (others => '0');

  attribute ASYNC_REG                     : string;
  attribute ASYNC_REG of r_flag_error_cdc : signal is "true";  -- place the
  -- registers together
  -----------------------------------------------------------------------------
  -- Atributos (ILA)
  -----------------------------------------------------------------------------
  attribute keep                          : string;
  attribute mark_debug                    : string;
  attribute keep of r_shift_clk           : signal is "true";
  attribute mark_Debug of r_shift_clk     : signal is "true";
  --
  attribute keep of r_cal_timeout         : signal is "true";
  attribute mark_Debug of r_cal_timeout   : signal is "true";
  --
  attribute keep of r_wait_ps_done        : signal is "true";
  attribute mark_Debug of r_wait_ps_done  : signal is "true";

begin

  -----------------------------------------------------------------------------
  -- This module resets MMCM when PXC_CNT is not reaching the expected value
  -- after a time defined by r_cal_timeout. This time should be 3x time_frame
  -- aprox. Is Known MMCM starting moment can affect when Cameralink CLK signal
  -- is sampled, being posible to sample on rising/falling edge times, driving
  -- to metastability issues.
  -- Resetting MCMM should shift sample times.
  -----------------------------------------------------------------------------

  process(CLK, LOCKED)
  begin
    if LOCKED = '0' then  -- asynchronous reset
      r_shift_clk      <= '0';
      r_wait_ps_done   <= '0';
      r_flag_error_cdc <= (others => '0');
    else
      if rising_edge(CLK) then
        r_shift_clk      <= '0';
        r_flag_error_cdc <= r_flag_error_cdc(1 downto 0) & r_flag_error_long;
        -----------------------------------------------------------------------
        -- Wait for PHASE SHIFTED process to be complete
        -----------------------------------------------------------------------
        if r_wait_ps_done = '0' then
          -----------------------------------------------------------------------
          -- Compare expected pixels with actual pixel count to reset the watchdog
          -----------------------------------------------------------------------
          if r_flag_error_cdc(2) = '1' then
            ---------------------------------------------------------------------
            -- Watchdog is resetted everytime a FV with the right ammount of
            -- pixels has been detected.
            ---------------------------------------------------------------------                                         
            r_shift_clk    <= '1';
            r_wait_ps_done <= '1';
          end if;
        end if;
        -----------------------------------------------------------------------
        -- PS_DONE free r_wait_ps_done flag
        -----------------------------------------------------------------------
        if PS_DONE = '1' then
          r_wait_ps_done <= '0';
        end if;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Genera una señal de error en el dominio de 7X. 
  -----------------------------------------------------------------------------

  PROC_ERROR_GEN : process(CLK_7X, LOCKED)
  begin
    if LOCKED = '0' then
      r_flag_error      <= '0';
      r_flag_error_vec  <= (others => '0');
      r_flag_error_long <= '0';
      r_out_of_locked   <= '1';
    else
      if rising_edge(CLK_7X)then
        r_flag_error      <= '0';
        r_flag_error_vec  <= r_flag_error_vec(4 downto 0) & r_flag_error;
        r_flag_error_long <= or_reduce(r_flag_error_vec);
        --
        r_cal_timeout     <= r_cal_timeout + 1;
        --
        if r_cal_timeout = C_TIMEOUT-1 then
          r_flag_error  <= '1';
          r_cal_timeout <= (others => '0');
        ---------------------------------------------------------------------
        -- Varias condiciones de error en CLK
        ---------------------------------------------------------------------
        elsif CLK_DATA_BUS(6 downto 0) = "0011100" then
          r_cal_timeout <= (others => '0');
        elsif CLK_DATA_BUS(6 downto 0) = "0001110" then
          r_cal_timeout <= (others => '0');
        elsif CLK_DATA_BUS(3 downto 0) = "1111" then
          r_flag_error <= '1';
        elsif CLK_DATA_BUS(4 downto 0) = "00000" then
          r_flag_error <= '1';
        elsif CLK_DATA_BUS(2 downto 0) = "010" then
          r_flag_error <= '1';
        elsif CLK_DATA_BUS(2 downto 0) = "101" then
          r_flag_error <= '1';
        end if;
        if r_out_of_locked = '1' then
          r_ool_cnt    <= r_ool_cnt + 1;
          r_flag_error <= '0';
          if r_ool_cnt = C_OOL_MAX-1 then
            r_out_of_locked <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;



  SHIFT_CLK <= r_shift_clk;


end RTL;
