------------------------------------------------------------------------------
-- Title      : Cameralink Receiver
-- Project    : zcu102_mpsoc
------------------------------------------------------------------------------
-- File        : clock_recovery.vhd
-- Author      : Daniel Jim�nez Mazure
-- Company     : DDR/TICH
-- Created     : 03/02/2019 - 15:07:29
-- Last update : 03/02/2019 - 15:07:29
-- Synthesizer : Vivado 2018.1
-- FPGA        : MPSoC Ultrascale +
------------------------------------------------------------------------------
-- Description: Error correction when sampling cameralink clock with IDDR
------------------------------------------------------------------------------
-- Copyright (c) 2019 DDR/TICH
------------------------------------------------------------------------------
-- Revisions  :
-- Date/Time                Version               Engineer
-- 16/06/2018 - 15:07:29      1.0             dasjimaz@gmail.com
-- Description :
-- Created
------------------------------------------------------------------------------
-- SVN Commit : $Date: 2019-01-02 16:10:01 +0200 (do., 05 ago. 2018) $
------------------------------------------------------------------------------
------------------------------------------------------------------------------
--* @cambio 03/02/2019 djmazure => versi�n inicial
------------------------------------------------------------------------------
-- Descripci�n:
-- Instancia de los IDDR y cambio de dominio a trav�s de una FIFO. Deserializa
-- el reloj cameralink y lo usa para determinar los l�mites del pixel.
------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_MISC.all;
use IEEE.NUMERIC_STD.all;
--use IEEE.MATH_REAL.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity clock_recovery is
  port (
    CLK_IDDR     : in  std_logic;
    CLK_DATA_IN  : in  std_logic_vector(8 downto 0);  -- upper 7 bits
    CLK_DATA_DFE : out std_logic_vector(8 downto 0)
    );
end clock_recovery;

architecture RTL of clock_recovery is

begin

  process
  begin
    s_error_bit1 <= '0';
    s_error_bit0 <= '0';
    if CLK_DATA_IN(8 downto 2) = "0011100" then
      if CLK_DATA_IN(1) = '1' then      -- fallo
        s_error_bit1 <= '1';
      end if;
      if CLK_DATA_IN(0) = '1' then
        s_error_bit0 <= '1';
      end if;
    end if;
  end process;

  CLK_DATA_DFE <= CLK_DATA_IN when s_error_bit0



  -- process(CLK_IDDR)
  -- begin
  --   if rising_edge(CLK_IDDR) then
  --     if CLK_DATA_IN = 

  --   end if;
  -- end process;



end RTL;
