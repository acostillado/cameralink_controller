------------------------------------------------------------------------------
-- Title      : Cameralink Receiver
-- Project    : zcu102_mpsoc
------------------------------------------------------------------------------
-- File        : cameralink_receiver.vhd
-- Author      : Daniel Jim�nez Mazure
-- Company     : DDR/TICH
-- Created     : 16/06/2018 - 15:07:29
-- Last update : 17/10/2019 - 18:17:23
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
-- SVN Commit : $Date: 2018-08-05 16:10:01 +0200 (do., 05 ago. 2018) $
------------------------------------------------------------------------------
------------------------------------------------------------------------------
--* @cambio 16/06/2018 djmazure => versi�n inicial
--* @cambio 17/10/2019 djmazure => Controlador refactorizado y con gen�rico
-- para adaptarse a la tarjeta de trenz
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

entity cameralink_receiver is
  generic(
    G_INVERTED_POLARITY : integer := 0
    );
  port (
    X_DATA_IN    : in  std_logic_vector(3 downto 0);
    FPGA_IN_DATA : out std_logic_vector(27 downto 0);
    CLK_7X       : in  std_logic;       -- 7x for iserdes, 3.5x for iddr
    CLK_7X_180   : in  std_logic;       -- 7x 180 degrees      
    CLK_1X       : in  std_logic;
    LOCKED       : in  std_logic;
    CLK_CL_DATA  : in  std_logic;
    CLK_DATA_BUS : out std_logic_vector(7 downto 0);
    LED_OUT      : out std_logic_vector(3 downto 0)  --7x domain 

    );
end cameralink_receiver;


architecture with_IDDRE1 of cameralink_receiver is

  -----------------------------------------------------------------------------
  -- Constantes
  -----------------------------------------------------------------------------
  constant C_TIMEOUT     : unsigned(9 downto 0) := to_unsigned(1000, 10);
  constant C_LOAD_CYCLES : unsigned(4 downto 0) := to_unsigned(20, 5);

  ------------------------------------------------------------------------------
  -- TIPOS
  ------------------------------------------------------------------------------
  type t_fsm_training is (
    FSM_IDLE,
    FSM_TRAINING,
    FSM_LOAD_FIFO,
    FSM_SYNCED
    );

  -----------------------------------------------------------------------------
  -- Componentes
  -----------------------------------------------------------------------------

  component fifo_cameralink_cdc
    port (
      srst        : in  std_logic;
      wr_clk      : in  std_logic;
      rd_clk      : in  std_logic;
      din         : in  std_logic_vector(27 downto 0);
      wr_en       : in  std_logic;
      rd_en       : in  std_logic;
      dout        : out std_logic_vector(27 downto 0);
      full        : out std_logic;
      empty       : out std_logic;
      wr_rst_busy : out std_logic;
      rd_rst_busy : out std_logic
      );
  end component;

  -----------------------------------------------------------------------------
  -- Se�ales
  -----------------------------------------------------------------------------
  signal Q1, Q2               : std_logic_vector(3 downto 0);
  --
  signal r_15bit_vector_line0 : std_logic_vector(14 downto 0) := (others => '0');
  signal r_15bit_vector_line1 : std_logic_vector(14 downto 0) := (others => '0');
  signal r_15bit_vector_line2 : std_logic_vector(14 downto 0) := (others => '0');
  signal r_15bit_vector_line3 : std_logic_vector(14 downto 0) := (others => '0');
  signal s_rst                : std_logic;
  --
  signal empty, full          : std_logic;
  signal r_fifo_full          : std_logic                     := '0';
  signal r_fifo_empty         : std_logic                     := '0';
  signal r_fifo_rd_en         : std_logic                     := '0';
  signal clk_7x_inv           : std_logic;
  --
  signal Q1_CL_CLK            : std_logic;
  signal Q2_CL_CLK            : std_logic;
  signal r_clk_data           : std_logic_vector(13 downto 0) := (others => '0');
  ------------------------------------------------------------------------------
  -- FSM
  ------------------------------------------------------------------------------
  -- M�quina de estados
  signal r_fsm_training       : t_fsm_training                := FSM_IDLE;
  signal n_fsm_training       : t_fsm_training;

  -----------------------------------------------------------------------------
  -- Se�ales FSM
  -----------------------------------------------------------------------------

  signal r_training_success : std_logic                     := '0';
  signal r_sync_lost        : std_logic                     := '0';
  signal r_sync_search1     : std_logic                     := '0';
  signal r_sync_search2     : std_logic                     := '0';
  signal r_fifo_wr_en       : std_logic                     := '0';
  signal s_data_fifo_in     : std_logic_vector(27 downto 0) := (others => '0');
  signal r_pixelZero        : std_logic_vector(27 downto 0) := (others => '0');
  signal r_pixelOne         : std_logic_vector(27 downto 0) := (others => '0');
  --
  signal n_training_success : std_logic;
  signal n_sync_lost        : std_logic;
  signal n_sync_search1     : std_logic;
  signal n_sync_search2     : std_logic;
  signal n_fifo_wr_en       : std_logic;
  signal n_pixelZero        : std_logic_vector(27 downto 0);
  signal n_pixelOne         : std_logic_vector(27 downto 0);
  --
  signal r_state            : std_logic_vector(1 downto 0)  := "00";
  signal n_state            : std_logic_vector(1 downto 0);
  --
  signal s_fifo_wr_en       : std_logic;
  signal n_wr_en            : std_logic;
  signal r_wr_en            : std_logic                     := '0';
  signal r2_wr_en           : std_logic                     := '0';
  --
  signal r_clk_timeout      : unsigned(7 downto 0)          := (others => '0');
  signal n_clk_timeout      : unsigned(7 downto 0);




  -----------------------------------------------------------------------------
  -- Atributos (ILA)
  -----------------------------------------------------------------------------
  attribute keep                               : string;
  attribute mark_debug                         : string;
  attribute keep of r_clk_data                 : signal is "true";
  attribute mark_Debug of r_clk_data           : signal is "true";
  attribute keep of r_wr_en                    : signal is "true";
  attribute mark_Debug of r_wr_en              : signal is "true";
  attribute keep of r_fifo_rd_en               : signal is "true";
  attribute mark_Debug of r_fifo_rd_en         : signal is "true";
  attribute keep of r_fifo_full                : signal is "true";
  attribute mark_Debug of r_fifo_full          : signal is "true";
  attribute keep of r_15bit_vector_line0       : signal is "true";
  attribute mark_Debug of r_15bit_vector_line0 : signal is "true";
  attribute keep of r_15bit_vector_line1       : signal is "true";
  attribute mark_Debug of r_15bit_vector_line1 : signal is "true";
  attribute keep of r_15bit_vector_line2       : signal is "true";
  attribute mark_Debug of r_15bit_vector_line2 : signal is "true";
  attribute keep of r_15bit_vector_line3       : signal is "true";
  attribute mark_Debug of r_15bit_vector_line3 : signal is "true";
  attribute keep of r_sync_search1             : signal is "true";
  attribute mark_Debug of r_sync_search1       : signal is "true";
  attribute keep of r_sync_search2             : signal is "true";
  attribute mark_Debug of r_sync_search2       : signal is "true";

begin  -- architecture with_IDDRE1

  s_rst      <= not LOCKED;
  clk_7x_inv <= not CLK_7X;             -- DRC oblies to use local inversion
  -- and not other net as clk_7x_180

  generate_iddr4 : for i in 0 to 3 generate

    IDDRE1_inst : IDDRE1
      generic map (
        DDR_CLK_EDGE => "SAME_EDGE_PIPELINED"  -- IDDRE1 mode (OPPOSITE_EDGE, SAME_EDGE, SAME_EDGE_PIPELINED)
        )
      port map (
        Q1 => Q1(i),         -- 1-bit output: Registered parallel output 1
        Q2 => Q2(i),         -- 1-bit output: Registered parallel output 2
        C  => CLK_7X,        -- 1-bit input: High-speed clock -- 280MHZ
        CB => clk_7x_inv,    -- 1-bit input: Inversion of High-speed clock C
        D  => X_DATA_IN(i),             -- 1-bit input: Serial Data Input
        R  => s_rst                     -- 1-bit input: Active High Async Reset
        );

  end generate generate_iddr4;

  IDDRE1_clk : IDDRE1
    generic map (
      DDR_CLK_EDGE => "SAME_EDGE_PIPELINED"  -- IDDRE1 mode (OPPOSITE_EDGE, SAME_EDGE, SAME_EDGE_PIPELINED)                  -- Optional inversion for C
      )
    port map (
      Q1 => Q1_CL_CLK,   -- 1-bit output: Registered parallel output 1
      Q2 => Q2_CL_CLK,   -- 1-bit output: Registered parallel output 2
      C  => CLK_7X,      -- 1-bit input: High-speed clock -- 280MHZ
      CB => clk_7x_inv,  -- 1-bit input: Inversion of High-speed clock C
      D  => CLK_CL_DATA,                -- 1-bit input: Serial Data Input
      R  => s_rst                       -- 1-bit input: Active High Async Reset
      );

  -- lets try a 56 bit vector with 7 * (8) X_DATA_IN _values



  WRITE_VECTOR_DESERIALIZED : process(CLK_7X)
  begin
    if rising_edge(CLK_7X) then
      r_15bit_vector_line0 <= r_15bit_vector_line0(12 downto 0) & Q1(0) & Q2(0);
      r_15bit_vector_line1 <= r_15bit_vector_line1(12 downto 0) & Q1(1) & Q2(1);
      r_15bit_vector_line2 <= r_15bit_vector_line2(12 downto 0) & Q1(2) & Q2(2);
      r_15bit_vector_line3 <= r_15bit_vector_line3(12 downto 0) & Q1(3) & Q2(3);
      --
      r_clk_data           <= r_clk_data(11 downto 0) & Q1_CL_CLK & Q2_CL_CLK;
      --
      r_fifo_full          <= full;
      if G_INVERTED_POLARITY = 1 then
        r_15bit_vector_line0 <= r_15bit_vector_line0(12 downto 0) & (not Q1(0)) & (not Q2(0));
      end if;
    end if;
  end process;


  -----------------------------------------------------------------------------
  -- FSM: Busca el sincronismo con el reloj deserializado
  -----------------------------------------------------------------------------
  process(CLK_7X)
  begin
    if rising_edge(CLK_7X) then
      if s_rst = '1' then
        r_fsm_training     <= FSM_IDLE;
        r_training_success <= '0';
        r_sync_search1     <= '0';
        r_sync_search2     <= '0';
        r_wr_en            <= '0';
        r2_wr_en           <= '0';
        r_pixelZero        <= (others => '0');
        r_pixelOne         <= (others => '0');
      else
        r_fsm_training     <= n_fsm_training;
        r_training_success <= n_training_success;
        r_sync_search1     <= n_sync_search1;
        r_sync_search2     <= n_sync_search2;
        r_wr_en            <= n_wr_en;
        r2_wr_en           <= r_wr_en;
        --
        r_pixelZero        <= n_pixelZero;
        r_pixelOne         <= n_pixelOne;
        --
        r_clk_timeout      <= n_clk_timeout;
      end if;
    end if;
  end process;

  -- NEXT STATE LOGIC

  process(r_fsm_training, LOCKED, r_training_success,
          r_clk_data, r_sync_search1, r_sync_search2, r_pixelZero,
          r_15bit_vector_line0, r_15bit_vector_line1, r_15bit_vector_line2,
          r_15bit_vector_line3, r_pixelOne,
          r_clk_timeout)
  begin
    n_fsm_training     <= r_fsm_training;
    n_training_success <= r_training_success;
    n_sync_search1     <= r_sync_search1;
    n_sync_search2     <= r_sync_search2;
    n_wr_en            <= '0';
    n_pixelZero        <= r_pixelZero;  -- could be others => 0
    n_pixelOne         <= r_pixelOne;   -- need to keep the value
    --
    n_clk_timeout      <= r_clk_timeout;
    -- 
    case (r_fsm_training) is
      when FSM_IDLE =>
        n_state <= "00";
        if LOCKED = '1' then
          n_fsm_training <= FSM_TRAINING;
        end if;
      when FSM_TRAINING =>
        n_state            <= "01";
        n_training_success <= '1';
        n_sync_search1     <= '0';
        n_sync_search2     <= '0';
        n_fsm_training     <= FSM_SYNCED;
        if r_clk_data(13 downto 0) = "00111000011100" then
          n_sync_search1 <= '1';
        elsif r_clk_data(13 downto 0) = "01110000111001" then
          n_sync_search2 <= '1';
        else
          n_training_success <= '0';
          n_fsm_training     <= FSM_TRAINING;
        end if;
      when FSM_SYNCED =>
        n_state <= "10";
        -----------------------------------------------------------------------
        -- Aqui busco el patron del reloj deserializado y doy el WREN cuando lo
        -- encuentre, para cargar los datos en la FIFO.
        -----------------------------------------------------------------------
        n_wr_en <= '0';                 -- se mantiene si se alinea el reloj

        n_clk_timeout <= r_clk_timeout + 1;

        if r_sync_search1 = '1' then
          if r_clk_data(13 downto 0) = "00111000011100" then
            n_pixelZero(6 downto 0)   <= r_15bit_vector_line0(6 downto 0);
            n_pixelZero(13 downto 7)  <= r_15bit_vector_line1(6 downto 0);
            n_pixelZero(20 downto 14) <= r_15bit_vector_line2(6 downto 0);
            n_pixelZero(27 downto 21) <= r_15bit_vector_line3(6 downto 0);
            --
            n_pixelOne(6 downto 0)    <= r_15bit_vector_line0(13 downto 7);
            n_pixelOne(13 downto 7)   <= r_15bit_vector_line1(13 downto 7);
            n_pixelOne(20 downto 14)  <= r_15bit_vector_line2(13 downto 7);
            n_pixelOne(27 downto 21)  <= r_15bit_vector_line3(13 downto 7);
            --
            n_wr_en                   <= '1';
            --
            n_clk_timeout             <= (others => '0');
          --
          end if;
        end if;

        if r_sync_search2 = '1' then

          if r_clk_data(13 downto 0) = "01110000111000" then
            n_pixelZero(6 downto 0)   <= r_15bit_vector_line0(7 downto 1);
            n_pixelZero(13 downto 7)  <= r_15bit_vector_line1(7 downto 1);
            n_pixelZero(20 downto 14) <= r_15bit_vector_line2(7 downto 1);
            n_pixelZero(27 downto 21) <= r_15bit_vector_line3(7 downto 1);
            --
            n_pixelOne(6 downto 0)    <= r_15bit_vector_line0(14 downto 8);
            n_pixelOne(13 downto 7)   <= r_15bit_vector_line1(14 downto 8);
            n_pixelOne(20 downto 14)  <= r_15bit_vector_line2(14 downto 8);
            n_pixelOne(27 downto 21)  <= r_15bit_vector_line3(14 downto 8);
            --
            n_wr_en                   <= '1';
            --
            n_clk_timeout             <= (others => '0');
          -- 
          end if;
        end if;

      when others =>
        n_state        <= "11";
        n_fsm_training <= FSM_IDLE;
    end case;
  end process;

  -----------------------------------------------------------------------------
  -- FIFO CDC: Voy a leer siempre que hay algo en la FIFO
  -----------------------------------------------------------------------------

  READ_FIFO_PROC : process(CLK_1X)
  begin
    if rising_edge(CLK_1X) then
      r_fifo_rd_en <= '0';
      if empty = '0' then
        r_fifo_rd_en <= '1';
      end if;
    end if;
  end process;


  s_data_fifo_in <= r_pixelZero when r2_wr_en = '1' else
                    r_pixelOne when r_wr_en = '1' else
                    (others => '0');

  s_fifo_wr_en <= r_wr_en or r2_wr_en;


  inst_fifo_cameralink_cdc : fifo_cameralink_cdc
    port map (
      srst   => s_rst,
      wr_clk => CLK_7X,
      rd_clk => CLK_1X,
      din    => s_data_fifo_in,
      wr_en  => s_fifo_wr_en,
      rd_en  => r_fifo_rd_en,
      dout   => FPGA_IN_DATA,
      full   => full,
      empty  => empty
      );

  -----------------------------------------------------------------------------
  -- Salidas
  -----------------------------------------------------------------------------

  LED_OUT(0) <= r_sync_search1;
  LED_OUT(1) <= r_sync_search2;
  LED_OUT(2) <= r_training_success;
  LED_OUT(3) <= r_fifo_full;
  
  CLK_DATA_BUS <= r_clk_data(7 downto 0);



end architecture with_IDDRE1;
