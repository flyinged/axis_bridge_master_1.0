--------------------------------------------------------------------------------
--                       Paul Scherrer Institute (PSI)
--------------------------------------------------------------------------------
-- Unit    : axi_bridge_master_v1_0.vhd
-- Author  : Goran Marinkovic, Section Diagnostic
-- Version : $Revision: 1.22 $
--------------------------------------------------------------------------------
-- Copyright© PSI, Section Diagnostic
--------------------------------------------------------------------------------
-- Comment : This is the top file for the AXI bridge.
--------------------------------------------------------------------------------
-- Std. library (platform) -----------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library axis_bridge_master_v1_0_lib;
use axis_bridge_master_v1_0_lib.all;

entity axis_bridge_master_v1_0 is
   generic
   (
      --------------------------------------------------------------------------
      -- Stream
      --------------------------------------------------------------------------
      K_SOF                       : std_logic_vector( 7 downto  0) := X"FB"; -- K27.7
      K_EOF                       : std_logic_vector( 7 downto  0) := X"FD"; -- K29.7
      K_ERR                       : std_logic_vector( 7 downto  0) := X"FE"; -- K30.7
      K_INT                       : std_logic_vector( 7 downto  0) := X"DC"; -- K28.6
      --------------------------------------------------------------------------
      -- AXI Master
      --------------------------------------------------------------------------
      TIMEOUT_CYCLES              : integer := 125000000; --Master timeout in AXI_CLK cycles (set to 0 to disable timeout)
      POSTED_WRITES               : std_logic := '1'; --ML84 posted writes
      RX_ADDR_MASK                : std_logic_vector(31 downto  0) := X"FFFF_FFFF" --this value is ANDed with the RX address
      --C_M00_AXI_ID_WIDTH          : integer := 1
   );
   port
   (
      --------------------------------------------------------------------------
      -- Debug
      --------------------------------------------------------------------------
      debug_clk                   : out    std_logic;
      debug                       : out    std_logic_vector(255 downto  0);
      --------------------------------------------------------------------------
      -- System
      --------------------------------------------------------------------------
      AXI_ACLK                    : in    std_logic;
      AXI_ARESETN                 : in    std_logic;
      AXI_INT                     : in    std_logic;
      --------------------------------------------------------------------------
      -- MGT Stream Interface
      --------------------------------------------------------------------------
      LEGACY_MODE                 : in    std_logic;
      --AXI Stream Master (TX)
      M00_AXIS_TREADY             : in    std_logic;
      M00_AXIS_TVALID             : out   std_logic;
      M00_AXIS_TUSER              : out   std_logic_vector( 3 downto  0);
      M00_AXIS_TDATA              : out   std_logic_vector(31 downto  0);
      --AXI Stream Slave (RX)
      S00_AXIS_TREADY             : out   std_logic;
      S00_AXIS_TVALID             : in    std_logic;
      S00_AXIS_TUSER              : in    std_logic_vector( 3 downto  0);
      S00_AXIS_TDATA              : in    std_logic_vector(31 downto  0);
      --------------------------------------------------------------------------
      -- AXI Master
      --------------------------------------------------------------------------
      -- Write Address
      --M00_AXI_AWID                : out   std_logic_vector(C_M00_AXI_ID_WIDTH - 1 downto 0);
      M00_AXI_AWADDR              : out   std_logic_vector(31 downto  0);
      M00_AXI_AWVALID             : out   std_logic;
      M00_AXI_AWREADY             : in    std_logic;
      M00_AXI_AWLEN               : out   std_logic_vector( 7 downto  0); -- NBEATS-1 (0=1 beat)
      M00_AXI_AWSIZE              : out   std_logic_vector( 2 downto  0); -- NBYTES=2^AWSIZE
      M00_AXI_AWBURST             : out   std_logic_vector( 1 downto  0); -- 00 fixed, 01 increment, 10 wrap
      -- Write Data
      M00_AXI_WDATA               : out   std_logic_vector(31 downto  0);
      M00_AXI_WLAST               : out   std_logic;
      M00_AXI_WVALID              : out   std_logic;
      M00_AXI_WREADY              : in    std_logic;
      M00_AXI_WSTRB               : out   std_logic_vector( 3 downto  0);
      -- Write response.
      --M00_AXI_BID                 : in    std_logic_vector(C_M00_AXI_ID_WIDTH - 1 downto 0);
      M00_AXI_BRESP               : in    std_logic_vector( 1 downto  0);
      M00_AXI_BVALID              : in    std_logic;
      M00_AXI_BREADY              : out   std_logic;
      -- Read address.
      --M00_AXI_ARID                : out   std_logic_vector(C_M00_AXI_ID_WIDTH - 1 downto 0);
      M00_AXI_ARADDR              : out   std_logic_vector(31 downto  0);
      M00_AXI_ARVALID             : out   std_logic;
      M00_AXI_ARREADY             : in    std_logic;
      M00_AXI_ARLEN               : out   std_logic_vector( 7 downto  0);
      M00_AXI_ARSIZE              : out   std_logic_vector( 2 downto  0);
      M00_AXI_ARBURST             : out   std_logic_vector( 1 downto  0);
      -- Read Data
      --M00_AXI_RID                 : in    std_logic_vector(C_M00_AXI_ID_WIDTH - 1 downto 0);
      M00_AXI_RDATA               : in    std_logic_vector(31 downto  0);
      M00_AXI_RLAST               : in    std_logic;
      M00_AXI_RVALID              : in    std_logic;
      M00_AXI_RREADY              : out   std_logic;
      M00_AXI_RRESP               : in    std_logic_vector( 1 downto  0)
   );
end axis_bridge_master_v1_0;

architecture structural of axis_bridge_master_v1_0 is

   -----------------------------------------------------------------------------
   -- Signals
   -----------------------------------------------------------------------------
   -- Interrupt interface
   signal   axi_int_edge          : std_logic_vector( 1 downto  0) := "00";
   signal   axi_int_pending       : std_logic := '0';
   -- RX PLB or AXI partner
   signal   legacy_mode_r         : std_logic := '0';
   attribute ASYNC_REG            : string;
   attribute ASYNC_REG of legacy_mode_r : signal is "TRUE";
   -- RX MGT
   signal   rx_tready             : std_logic := '0';
   -- RX frame
   signal   rx_frame_re           : std_logic := '0';
   signal   rx_frame_sof          : std_logic := '0';
   signal   rx_frame_eof          : std_logic := '0';
   signal   rx_frame_active       : std_logic := '0';

   signal   rx_frame_id_next      : unsigned( 3 downto  0) := (others => '0');
   signal   rx_frame_id_eq        : std_logic := '0';

   signal   rx_frame_opcode       : std_logic_vector( 3 downto  0) := X"0";
   -- RX FIFO
   signal   rx_fifo_rst           : std_logic := '0';

   signal   rx_fifo_d_we          : std_logic := '0';
   signal   rx_fifo_d_din         : std_logic_vector(35 downto  0) := (others => '0');
   signal   rx_fifo_d_af          : std_logic := '0';
   signal   rx_fifo_d_f           : std_logic := '0';

   signal   rx_fifo_d_re          : std_logic := '0';
   signal   rx_fifo_d_dout        : std_logic_vector(35 downto  0) := (others => '0');
   signal   rx_fifo_d_e           : std_logic := '0';
   signal   rx_fifo_d_ae          : std_logic := '0';

   signal   rx_fifo_i_we          : std_logic := '0';
   signal   rx_fifo_i_din         : std_logic_vector( 7 downto  0) := (others => '0');
   signal   rx_fifo_i_f           : std_logic := '0';

   signal   rx_fifo_i_re          : std_logic := '0';
   signal   rx_fifo_i_dout        : std_logic_vector( 7 downto  0) := (others => '0');
   signal   rx_fifo_i_e           : std_logic := '0';
   -- RX CRC32
   constant CRC_RESIDUAL          : std_logic_vector(31 downto 0) := X"1CDF4421";
   signal   rx_crc_rst            : std_logic := '0';
   signal   rx_crc_valid          : std_logic := '0';
   signal   rx_crc                : std_logic_vector(31 downto  0) := (others => '0');
   signal   rx_crc_err            : std_logic := '0';
   -- RX FSM
   --ML84 TODO: TIMEOUT as generic
   --constant TIMEOUT_CYCLES        : integer := 1000;  --ML84 CHANGED: 256 for longest transaction plus additional time for response
   signal   timeout_cnt           : integer; -- range 0 to TIMEOUT_CYCLES := TIMEOUT_CYCLES;
   signal   timeout               : std_logic;

   type state_type is
   (
      IDLE,
      ALIGN_DATA,
      HANDLE_DATA,
      DISCARD_INSTR,
      DISCARD_DATA,
      DISCARD_ALL,
      IRQ,
      RD_AXI_ADDR,
      RD_AXI_WAIT,
      RD_MGT_SOF,
      RD_MGT_CMD,
      RD_MGT_DATA,
      RD_MGT_CRC,
      RD_MGT_EOF,
      WR_AXI_ADDR,
      WR_AXI_DATA,
      WR_AXI_ACK,
      WR_MGT_SOF,
      WR_MGT_CMD,
      WR_MGT_CRC,
      WR_MGT_EOF
   );
   signal   state, s_r            : state_type;

   -- TX frame
   signal   K_IDL                 : std_logic_vector( 7 downto  0) := X"3C";
   signal   tx_frame_cmd          : std_logic_vector(31 downto  0) := (others => '0');
   -- TX CRC32
   signal   tx_crc_rst            : std_logic := '0';
   signal   tx_crc_valid          : std_logic := '0';
   signal   tx_crc                : std_logic_vector(31 downto  0) := (others => '0');
   -- TX MGT
   signal   tx_tvalid             : std_logic := '0';
   signal   tx_tuser              : std_logic_vector( 3 downto  0) := (others => '0');
   signal   tx_tdata              : std_logic_vector(31 downto  0) := (others => '0');
   -- AXI
   signal   m_araddr              : std_logic_vector(31 downto  0) := (others => '0');
   signal   m_arvalid             : std_logic := '0';
   signal   m_arlen               : std_logic_vector( 7 downto  0) := (others => '0');
   signal   m_arburst             : std_logic_vector( 1 downto  0) := (others => '0');

   signal   m_rdata               : std_logic_vector(31 downto  0) := (others => '0');
   signal   m_rready              : std_logic := '0';

   signal   m_awaddr              : std_logic_vector(31 downto  0) := (others => '0');
   signal   m_awvalid             : std_logic := '0';
   signal   m_awlen               : std_logic_vector( 7 downto  0) := (others => '0');
   signal   m_awlen_cnt           : unsigned( 7 downto  0) := (others => '0');
   signal   m_awburst             : std_logic_vector( 1 downto  0) := (others => '0');

   signal   m_wdata               : std_logic_vector(31 downto  0) := (others => '0');
   signal   m_wlast               : std_logic := '0';
   signal   m_wvalid              : std_logic := '0';
   signal   m_wstrb               : std_logic_vector( 3 downto  0) := (others => '0');

   signal   m_bready              : std_logic := '0';

   signal ififo_cnt : natural range 0 to 4095;
   signal dfifo_cnt : natural range 0 to 4095;
   signal ififo_alarm : std_logic;
   signal stat_gen_tout, stat_d_discard, stat_i_discard, stat_crc_err : unsigned(31 downto 0);

   -----------------------------------------------------------------------------
   -- Components
   -----------------------------------------------------------------------------
   component crc32_rtl is
   port
   (
      CRCCLK                      : in    std_logic;
      CRCRESET                    : in    std_logic;
      CRCDATAVALID                : in    std_logic;
      CRCIN                       : in    std_logic_vector(31 downto  0);
      CRCOUT                      : out   std_logic_vector(31 downto  0)
   );
   end component crc32_rtl;

   component rx_data_fifo IS
   port
   (
      clk                         : in    std_logic;
      rst                         : in    std_logic;
      din                         : in    std_logic_vector(35 downto  0);
      wr_en                       : in    std_logic;
      rd_en                       : in    std_logic;
      dout                        : out   std_logic_vector(35 downto  0);
      prog_empty                  : out   std_logic;
      prog_full                   : out   std_logic;
      full                        : out   std_logic;
      empty                       : out   std_logic
   );
   end component rx_data_fifo;

   component rx_info_fifo IS
   port
   (
      clk                         : in    std_logic;
      rst                         : in    std_logic;
      din                         : in    std_logic_vector( 7 downto  0);
      wr_en                       : in    std_logic;
      rd_en                       : in    std_logic;
      dout                        : out   std_logic_vector( 7 downto  0);
      full                        : out   std_logic;
      empty                       : out   std_logic
   );
   end component rx_info_fifo;

   signal state_encode : std_logic_vector(4 downto 0);
   signal last_states : std_logic_Vector(31 downto 0);
   signal timer, elapsed : unsigned(31 downto 0) := X"00000000";

   constant CSP_SET : natural := 1;

begin

   -----------------------------------------------------------------------------
   -- Debug
   -----------------------------------------------------------------------------
   CSP_SET0_G: if (CSP_SET = 0) generate
   -- Common
   debug_clk                      <= AXI_ACLK;

   -- State machine
   state_encode                   <= "00001" when (state = IDLE         ) else
                                     "00010" when (state = ALIGN_DATA   ) else
                                     "00011" when (state = HANDLE_DATA  ) else
                                     "00100" when (state = DISCARD_INSTR) else
                                     "00101" when (state = DISCARD_DATA ) else
                                     "00110" when (state = DISCARD_ALL  ) else
                                     "00111" when (state = IRQ          ) else
                                     "01000" when (state = RD_AXI_ADDR  ) else
                                     "01001" when (state = RD_AXI_WAIT  ) else
                                     "01010" when (state = RD_MGT_SOF   ) else
                                     "01011" when (state = RD_MGT_CMD   ) else
                                     "01100" when (state = RD_MGT_DATA  ) else
                                     "01101" when (state = RD_MGT_CRC   ) else
                                     "01110" when (state = RD_MGT_EOF   ) else
                                     "01111" when (state = WR_AXI_ADDR  ) else
                                     "10000" when (state = WR_AXI_DATA  ) else
                                     "10001" when (state = WR_AXI_ACK   ) else
                                     "10010" when (state = WR_MGT_SOF   ) else
                                     "10011" when (state = WR_MGT_CMD   ) else
                                     "10100" when (state = WR_MGT_CRC   ) else
                                     "10101" when (state = WR_MGT_EOF   ) else "00000";
      
   debug(04 downto 00) <= state_encode;
   debug(           5) <= timeout;

   debug(31 downto 6) <= (others => '0');

   DBG_P : process(AXI_ACLK)
   begin
       if rising_edge(AXI_ACLK) then
           if m_arvalid = '1' and M00_AXI_ARREADY = '1' then --address sampled
               debug(63 downto 32) <= m_araddr;
               timer <= X"00000001";
           elsif m_rready = '1' and M00_AXI_RVALID = '1' then --response received
               elapsed <= timer;
           else 
               timer <= timer+1;
           end if;
       end if;
   end process;

   --store last 4 states (debug(63:32) = S(t-3) & S(t-2) & S(t-1) & S(t)
   STATE_TRACE_P : process(AXI_ACLK)
   begin
       if rising_edge(AXI_ACLK) then
           if last_states(4 downto 0) /= state_encode then
               last_states(07 downto 00) <= "000" & state_encode;
               last_states(15 downto 08) <= last_states(07 downto 00);
               last_states(23 downto 16) <= last_states(15 downto 08);
               last_states(31 downto 24) <= last_states(23 downto 16);
           end if;
       end if;
   end process;

   debug(95 downto 64)   <= std_logic_vector(timer);
   debug(          96)   <= m_arvalid;-- and M00_AXI_ARREADY = '1';
   debug(          97)   <= m_rready; -- and M00_AXI_RVALID = '1';
   debug(          98)   <= M00_AXI_ARREADY; --to compare with FSM state
   debug(          99)   <= M00_AXI_RVALID; --to compare with FSM state
   debug(159 downto 128) <= last_states;
   debug(191 downto 160) <= m_araddr;
   
   end generate; --CSP_SET0

   -----------------------------------------------------------------------------
   CSP_SET1_G: if (CSP_SET = 1) generate
   
       debug_clk                      <= AXI_ACLK;
       
       CSP_REG: process(AXI_ACLK)
       begin
           if rising_edge(AXI_ACLK) then
              debug(031 downto 000) <= m_araddr and RX_ADDR_MASK;
              debug(063 downto 032) <= M00_AXI_RDATA;
              debug(095 downto 064) <= tx_tdata;
              debug(103 downto 096) <= m_arlen; --8
              debug(107 downto 104) <= tx_tuser; --4
              debug(109 downto 108) <= m_arburst; --2
              debug(111 downto 110) <= M00_AXI_RRESP; --2
              debug(           112) <= m_arvalid;
              debug(           113) <= M00_AXI_ARREADY;
              debug(           114) <= M00_AXI_RLAST;
              debug(           115) <= M00_AXI_RVALID;
              debug(           116) <= m_rready;
              debug(           117) <= M00_AXIS_TREADY;
              debug(           118) <= tx_tvalid;
              debug(122 downto 119) <= "0000";
              debug(127 downto 123) <= state_encode; --5
          end if;
      end process;

   end generate; --CSP_SET1

   -----------------------------------------------------------------------------
   -- STATISTICS
   -----------------------------------------------------------------------------
   STATS_P : process(AXI_ACLK)
   begin
       if rising_edge(AXI_ACLK) then
           if (AXI_ARESETN = '0') then
               stat_gen_tout  <= (others => '0');
               stat_i_discard <= (others => '0');
               stat_d_discard <= (others => '0');
               stat_crc_err   <= (others => '0');
           else

               if timeout_cnt = 0 then
                   stat_gen_tout <= stat_gen_tout+1;
               end if;

               if state = DISCARD_INSTR then
                   stat_i_discard <= stat_i_discard+1;
               end if;
               
               if rx_fifo_i_we = '1' and rx_crc_err = '1' then
                   stat_crc_err <= stat_crc_err+1;
               end if;
               
               s_r <= state;
               if rx_fifo_d_re = '1' and (state = DISCARD_DATA or state = DISCARD_ALL or (state = ALIGN_DATA and s_r = ALIGN_DATA)) then
                   stat_d_discard <= stat_d_discard+1;
               end if;
           end if;
       end if;
   end process;
   
   -----------------------------------------------------------------------------
   -- Interrupt interface
   -----------------------------------------------------------------------------
   IRQ_SAMPLE_P : process(AXI_ACLK)
   begin
      if rising_edge(AXI_ACLK) then
         axi_int_edge             <= axi_int_edge( 0) & AXI_INT;
         if (axi_int_edge = "01") then
            axi_int_pending       <= '1';
         elsif (state = IRQ) then
            axi_int_pending       <= '0';
         end if;
      end if;
   end process;

   -----------------------------------------------------------------------------
   -- PLB / AXI bridge? CAUTION: LEGACY_MODE can be async to AXI_ACLK hence
   -- has to be resynchronized. However the LEGACY_MODE should be quasi static
   -- hence no problems are expected here
   -----------------------------------------------------------------------------
   MODE_SAMPLE_P : process(AXI_ACLK)
   begin
      if rising_edge(AXI_ACLK) then
         legacy_mode_r <= LEGACY_MODE;
      end if;
   end process;

   -----------------------------------------------------------------------------
   -- RX MGT interface
   -----------------------------------------------------------------------------
   rx_tready                      <= AXI_ARESETN and not rx_fifo_d_f and not rx_fifo_i_f; -- receive data when not under reset, and fifo not full
   S00_AXIS_TREADY                <= rx_tready;

   -----------------------------------------------------------------------------
   -- RX frame new word
   -----------------------------------------------------------------------------
   rx_frame_re                    <= rx_tready and S00_AXIS_TVALID;             -- rx_frame_re marks valid RX data

   -----------------------------------------------------------------------------
   -- RX frame detect start (SOF) and end (EOF)
   -----------------------------------------------------------------------------
   rx_frame_sof                   <= '1' when ((rx_frame_re = '1') and (S00_AXIS_TUSER( 3 downto  2) = "01") and (S00_AXIS_TDATA(31 downto 16) = (X"00" & K_SOF))) else '0';
   --ML84 CHANGE: generate EOF only after a SOF has been received (so that random bad data is less likely to cause a write to the INFO FIFO)
   --rx_frame_eof                   <= '1' when ((rx_frame_re = '1') and (S00_AXIS_TUSER( 1 downto  0) = "01") and (S00_AXIS_TDATA(15 downto  0) = (X"00" & K_EOF))) else '0';
   rx_frame_eof                   <= '1' when (
                                               (rx_frame_re = '1') and 
                                               (S00_AXIS_TUSER( 1 downto  0) = "01") and 
                                               (S00_AXIS_TDATA(15 downto  0) = (X"00" & K_EOF)) and 
                                               (rx_frame_active = '1') --ADDED
                                       ) else '0';

   -----------------------------------------------------------------------------
   -- RX frame active and id
   -----------------------------------------------------------------------------
   FRAME_ENVELOPE_P : process(AXI_ACLK)
   begin
      if rising_edge(AXI_ACLK) then
         if (AXI_ARESETN = '0') then
            rx_frame_active       <= '0';
         else
            if    (rx_frame_sof = '1') then
               rx_frame_active    <= '1';
            elsif (rx_frame_eof = '1') then
               rx_frame_active    <= '0';
            end if;
         end if;
      end if;
   end process;

   ID_COUNT_P : process(AXI_ACLK)
   begin
      if rising_edge(AXI_ACLK) then
         if (AXI_ARESETN = '0') then
            rx_frame_id_next      <= X"0";
         else
            if (rx_frame_sof = '1') then
               rx_frame_id_next   <= rx_frame_id_next + 1;
            end if;
         end if;
      end if;
   end process;

   -----------------------------------------------------------------------------
   -- RX frame CRC
   -----------------------------------------------------------------------------
   rx_crc_rst                     <= rx_frame_sof; -- clear crc calculation if rx_frame_sof is detected
   rx_crc_valid                   <= rx_frame_re and rx_frame_active and not rx_frame_eof;

   crc_rx_inst: entity axis_bridge_master_v1_0_lib.crc32_rtl
   port map
   (
      CRCCLK                      => AXI_ACLK,
      CRCRESET                    => rx_crc_rst,
      CRCDATAVALID                => rx_crc_valid,
      CRCIN                       => S00_AXIS_TDATA,
      CRCOUT                      => rx_crc
   );

   rx_crc_err                     <= '0' when (rx_crc = CRC_RESIDUAL) else '1';

   -----------------------------------------------------------------------------
   -- RX frame info FIFO
   -----------------------------------------------------------------------------
   rx_fifo_rst                    <= not AXI_ARESETN;

   rx_fifo_i_we                   <= rx_frame_eof;
   rx_fifo_i_din                  <= std_logic_vector(rx_frame_id_next) & "000" & rx_crc_err; --bit0 := CRC error must be '0' for packet to be accepted

   rx_info_fifo_inst: rx_info_fifo
   port map
   (
      clk                         => AXI_ACLK,
      rst                         => rx_fifo_rst,

      wr_en                       => rx_fifo_i_we,
      din                         => rx_fifo_i_din,
      full                        => rx_fifo_i_f,

      rd_en                       => rx_fifo_i_re,
      dout                        => rx_fifo_i_dout,
      empty                       => rx_fifo_i_e
   );

   rx_fifo_i_re                   <= not rx_fifo_i_e when ((state = HANDLE_DATA  ) or 
                                                           (state = DISCARD_INSTR)) else '0';

   IFIFO_ALARM_P : process(AXI_ACLK)
   begin
       if rising_edge(AXI_ACLK) then
           if (rx_fifo_rst = '1') then
               ififo_cnt <= 0;
           else
               if rx_fifo_i_we = '1' and rx_fifo_i_re = '0' then 
                   ififo_cnt <= ififo_cnt+1;
               elsif rx_fifo_i_we = '0' and rx_fifo_i_re = '1' and ififo_cnt > 0 then
                   ififo_cnt <= ififo_cnt-1;
               end if;
           end if;
       end if;
   end process;
   ififo_alarm <= '1' when ififo_cnt > 15 else '0';

   DFIFO_ALARM_P : process(AXI_ACLK)
   begin
       if rising_edge(AXI_ACLK) then
           if (rx_fifo_rst = '1') then
               dfifo_cnt <= 0;
           else
               if rx_fifo_d_we = '1' and rx_fifo_d_re = '0' then 
                   dfifo_cnt <= dfifo_cnt+1;
               elsif rx_fifo_d_we = '0' and rx_fifo_d_re = '1' and dfifo_cnt > 0 then
                   dfifo_cnt <= dfifo_cnt-1;
               end if;
           end if;
       end if;
   end process;

   -----------------------------------------------------------------------------
   -- RX data FIFO
   -----------------------------------------------------------------------------
   rx_fifo_d_we                   <= rx_frame_re and rx_frame_active and not rx_frame_eof;
   rx_fifo_d_din                  <= std_logic_vector(rx_frame_id_next) & S00_AXIS_TDATA; -- store also packet ID

   rx_data_fifo_inst: rx_data_fifo
   port map
   (
      clk                         => AXI_ACLK,
      rst                         => rx_fifo_rst,

      wr_en                       => rx_fifo_d_we,
      din                         => rx_fifo_d_din,
      prog_full                   => rx_fifo_d_af,
      full                        => rx_fifo_d_f,

      rd_en                       => rx_fifo_d_re,
      dout                        => rx_fifo_d_dout,
      prog_empty                  => rx_fifo_d_ae,
      empty                       => rx_fifo_d_e
   );

   rx_fifo_d_re                   <= not rx_fifo_d_e when (((state = ALIGN_DATA  ) and (rx_frame_id_eq = '0' )) or --pull DATA with non-matching ID
                                                           ((state = DISCARD_DATA) and (rx_frame_id_eq = '1' )) or --pull packet with BAD CRC
                                                           ((state = DISCARD_ALL ) and (rx_fifo_i_e    = '1' )) or --discard garbage
                                                           ((state = HANDLE_DATA )                            ) or --normal read
                                                           ((state = RD_AXI_ADDR ) and (M00_AXI_ARREADY = '1')) or --get read address
                                                           ((state = WR_AXI_ADDR ) and (M00_AXI_AWREADY = '1')) or --get write address
                                                           ((state = WR_AXI_DATA ) and (M00_AXI_WREADY  = '1'))) else '0'; --get write data

   -----------------------------------------------------------------------------
   -- Mating instruction and data
   -----------------------------------------------------------------------------
   rx_frame_id_eq <= '1' when (rx_fifo_i_dout( 7 downto  4) = rx_fifo_d_dout(35 downto 32)) else '0';

   -----------------------------------------------------------------------------
   -- RX data opcode
   -----------------------------------------------------------------------------
   -- supported RX opcodes
   --  1000 -- PLB write single
   --  1010 -- PLB write burst
   --  1100 -- PLB read  single
   --  1110 -- PLB read  burst
   --
   --  0000 -- AXI write single
   --  0010 -- AXI write burst
   --  0100 -- AXI read  single
   --  0110 -- AXI read  burst
   --
   -- unsupported RX opcodes
   --  codes 0x1, 0x3, 0x5, 0x7, 0x9 0xB, 0xD and 0xF are not supported
   rx_frame_opcode                <= legacy_mode_r      &
                                     rx_fifo_d_dout(31) & -- READ/WRITE_n
                                     rx_fifo_d_dout(28) & -- BURST/SINGLE_n
                                     rx_fifo_d_dout( 8);  -- RESP (only if AXI MODE)

   -----------------------------------------------------------------------------
   -- FSM
   -----------------------------------------------------------------------------
   MAIN_FSM : process(AXI_ACLK)
   begin
      if rising_edge(AXI_ACLK) then
         if (AXI_ARESETN = '0') then
            state                 <= IDLE;
         else
           case state is
               when IDLE =>
                  if (rx_fifo_i_e = '0') then -- new frame in fifo
                     if (rx_fifo_i_dout( 0) = '0') then -- No CRC error hence process opcode
                        state     <= ALIGN_DATA;
                     else --bad frame
                        state     <= DISCARD_INSTR; -- CRC error hence discard frame
                     end if;
                  --ML84 NEW: if instruction FIFO is empty and data FIFO is full, then flush data FIFO.
                  elsif (rx_fifo_d_f = '1') then
                     state <= DISCARD_ALL;
                  else --TODO: IRQ has lowest priority. It would be perhaps better to poll it regurarly (go to state IRQ always before IDLE?)
                     if (axi_int_pending = '1') then
                        state     <= IRQ;
                     end if;
                  end if;
               --------------------------------------------------------------------
               when IRQ =>
                  if (M00_AXIS_TREADY = '1') then
                     state        <= IDLE;
                  end if;
               --------------------------------------------------------------------
               when ALIGN_DATA =>
                  --Info FIFO notified that a new VALID frame was written to data FIFO
                  --If ID does not match, read data FIFO until ID matches or FIFO becomes empty.
                  --If data FIFO becomes empty, then discard instruction.
                  if (rx_frame_id_eq = '1') then -- Instruction and data match : process packet
                     state        <= HANDLE_DATA;
                  --ML84 NOTE: following condition will never be met and could be commented out:
                  --  the current state is reached only if a good packet has been written to data FIFO
                  --  (ie: rx_fifo_i_e = '0' and rx_fifo_i_dout(0) = '0' => no CRC error).
                  --  Thus reading the data fifo will inevitably find the data that will cause rx_frame_id_eq = '1'.
                  elsif (rx_fifo_d_e = '1') then --bad data: read data FIFO until ID matches or FIFO empty 
                     state        <= DISCARD_INSTR;
                  end if;
               when HANDLE_DATA =>
                  case rx_frame_opcode is
                  when "0000" => -- AXI write single
                     state        <= WR_AXI_ADDR;
                  when "0010" => -- AXI write burst
                     state        <= WR_AXI_ADDR;
                  when "0100" => -- AXI read single
                     state        <= RD_AXI_ADDR;
                  when "0110" => -- AXI read burst
                     state        <= RD_AXI_ADDR;
                  when "1000" => -- PLB write single
                     state        <= WR_AXI_ADDR;
                  when "1010" => -- PLB write burst
                     state        <= WR_AXI_ADDR;
                  when "1100" => -- PLB read single
                     state        <= RD_AXI_ADDR;
                  when "1110" => -- PLB read burst
                     state        <= RD_AXI_ADDR;
                  when others =>
                     state        <= DISCARD_DATA; -- Unsupported opcode hence discard frame
                  end case;
               --------------------------------------------------------------------
               when DISCARD_INSTR =>
                  state           <= DISCARD_DATA;
               when DISCARD_DATA =>
                  if ((rx_frame_id_eq = '0') or (rx_fifo_d_e = '1')) then
                     state        <= IDLE;
                  end if;
               when DISCARD_ALL =>
                  if ((rx_fifo_d_e = '1') or (rx_fifo_i_e = '0')) then
                     state        <= IDLE;
                  end if;
               --------------------------------------------------------------------
               when RD_AXI_ADDR =>
                  if (rx_fifo_d_re = '1') then -- address sampled and put to AXI master port, go on
                     state        <= RD_AXI_WAIT;
                  end if;
               when RD_AXI_WAIT =>
                   if (M00_AXI_RVALID = '1') then -- read data is available
                     state        <= RD_MGT_SOF;
                  end if;
               when RD_MGT_SOF => -- send start of packet (wait first for data to be available)
                  if (M00_AXIS_TREADY = '1') then -- data available: send Start of packet
                     if (legacy_mode_r = '0') then
                        state     <= RD_MGT_CMD;  -- in AXI mode send command also for reads
                     else
                        state     <= RD_MGT_DATA; -- in PLB mode send only data
                     end if;
                  end if;
               when RD_MGT_CMD =>
                  if (M00_AXIS_TREADY = '1') then
                     state        <= RD_MGT_DATA;
                  end if;
               when RD_MGT_DATA =>
                  if (M00_AXIS_TREADY = '1') then
                      if (M00_AXI_RLAST = '1') then 
                        state     <= RD_MGT_CRC;
                     end if;
                  end if;
               when RD_MGT_CRC =>
                  if (M00_AXIS_TREADY = '1') then
                     state        <= RD_MGT_EOF;
                  end if;
               when RD_MGT_EOF =>
                  if (M00_AXIS_TREADY = '1') then
                     --ML84 CHANGE2: Discarding data now could cause loss of queued transactions
                     --state     <= DISCARD_DATA; -- PLB don't send anything
                     state     <= IDLE; -- PLB don't send anything
                  end if;
               --------------------------------------------------------------------
               when WR_AXI_ADDR =>
                  if (rx_fifo_d_re = '1') then -- address sampled, go on
                     state        <= WR_AXI_DATA;
                  end if;
               when WR_AXI_DATA =>
                  if (rx_fifo_d_re = '1') then -- data sampled, check/increment data counter
                     if (m_awlen_cnt = unsigned(m_awlen)) then
                        --ML84 posted writes
                        if POSTED_WRITES = '1' then
                            state     <= IDLE;
                        else
                            state     <= WR_AXI_ACK;
                        end if;
                     end if;
                  end if;
               when WR_AXI_ACK =>
                  if (M00_AXI_BVALID = '1') then -- always wait for RESP
                     if (legacy_mode_r = '0') then
                        state     <= WR_MGT_SOF; -- AXI send response packet
                     else
                        --ML84 CHANGE: Discarding data now could cause loss of queued transactions
                        --state     <= DISCARD_DATA; -- PLB don't send anything
                        state     <= IDLE; -- PLB don't send anything
                     end if;
                  end if;
               when WR_MGT_SOF =>
                  if (M00_AXIS_TREADY = '1') then
                     state        <= WR_MGT_CMD;
                  end if;
               when WR_MGT_CMD =>
                  if (M00_AXIS_TREADY = '1') then
                     state        <= WR_MGT_CRC;
                  end if;
               when WR_MGT_CRC =>
                  if (M00_AXIS_TREADY = '1') then
                     state        <= WR_MGT_EOF;
                  end if;
               when WR_MGT_EOF =>
                  if (M00_AXIS_TREADY = '1') then
                     --ML84 CHANGE2: Discarding data now could cause loss of queued transactions
                     --state     <= DISCARD_DATA; -- PLB don't send anything
                     state     <= IDLE; -- PLB don't send anything
                  end if;
               --------------------------------------------------------------------
               when others =>
                  state           <= IDLE;
           end case;
         end if;
      end if;
   end process;

   -----------------------------------------------------------------------------
   -- Time out (kept only for debug purposes)
   -----------------------------------------------------------------------------
   TIMEOUT_P : process(AXI_ACLK)
   begin
      if rising_edge(AXI_ACLK) then

         if (state = RD_AXI_WAIT) and (timeout_cnt /= 0) then
            timeout_cnt           <= timeout_cnt - 1;
         else
            timeout_cnt           <= TIMEOUT_CYCLES;
         end if;

      end if;
   end process;
   timeout <= '1' when (timeout_cnt = 0) and (TIMEOUT_CYCLES /= 0) else '0';

   -----------------------------------------------------------------------------
   -- TX command
   -----------------------------------------------------------------------------
   TX_CMD_P : process(AXI_ACLK)
   begin
      if rising_edge(AXI_ACLK) then
         case state is
         when RD_AXI_WAIT =>
            if (M00_AXI_RVALID = '1') then
               tx_frame_cmd(31)           <= '1'; -- read
               tx_frame_cmd(30 downto  9) <= (others => '0');
               tx_frame_cmd( 8)           <= '1'; -- response
               tx_frame_cmd( 7 downto  0) <= m_arlen;
            end if;
         when WR_AXI_ACK =>
            if (M00_AXI_BVALID = '1') then
               tx_frame_cmd(31)           <= '0'; -- write
               tx_frame_cmd(30 downto  9) <= (others => '0');
               tx_frame_cmd( 8)           <= '1'; -- response
               tx_frame_cmd( 7 downto  2) <= (others => '0');
               tx_frame_cmd( 1 downto  0) <= M00_AXI_BRESP;
            end if;
         when others =>
            NULL;
         end case;
      end if;
   end process;

   -----------------------------------------------------------------------------
   -- TX CRC
   -----------------------------------------------------------------------------
   tx_crc_rst                     <= '1' when ((state = RD_MGT_SOF) or (state = WR_MGT_SOF)) else '0';
   --tx_crc_valid                   <= '1' when ((M00_AXIS_TREADY = '1') and ((state = RD_MGT_CMD) or (state = RD_MGT_DATA) or (state = WR_MGT_CMD))) else '0';
   tx_crc_valid                   <= '1' when (
                                                (tx_tvalid = '1') and 
                                                ((state = RD_MGT_CMD) or (state = RD_MGT_DATA) or (state = WR_MGT_CMD))
                                              ) else '0';

   crc_tx_inst: entity axis_bridge_master_v1_0_lib.crc32_rtl
   port map
   (
      CRCCLK                      => AXI_ACLK,
      CRCRESET                    => tx_crc_rst,
      CRCDATAVALID                => tx_crc_valid,
      CRCIN                       => tx_tdata,
      CRCOUT                      => tx_crc
   );

   -----------------------------------------------------------------------------
   -- AXI Streaming Master (MGT TX)
   -----------------------------------------------------------------------------
   K_IDL                          <= X"3C" when (legacy_mode_r = '0') else X"BC";

   tx_tvalid                      <= M00_AXIS_TREADY when ((state = IRQ        ) or
                                                           (state = WR_MGT_SOF ) or
                                                           (state = WR_MGT_CMD ) or
                                                           (state = WR_MGT_CRC ) or
                                                           (state = WR_MGT_EOF ) or
                                                           (state = RD_MGT_SOF ) or
                                                           (state = RD_MGT_CMD ) or
                                                           (state = RD_MGT_DATA and M00_AXI_RVALID = '1') or
                                                           (state = RD_MGT_CRC ) or
                                                           (state = RD_MGT_EOF )) else '0';

   tx_tuser                       <= "0101" when ((state = IRQ       )                        ) else
                                     "0101" when ((state = WR_MGT_SOF) or (state = RD_MGT_SOF)) else
                                     "0101" when ((state = WR_MGT_EOF) or (state = RD_MGT_EOF)) else "0000";

   tx_tdata                       <= m_rdata                         when ((state = RD_MGT_DATA)                        ) else
                                     (X"00" & K_IDL & X"00" & K_INT) when ((state = IRQ        )                        ) else
                                     (X"00" & K_SOF & X"00" & K_IDL) when ((state = RD_MGT_SOF ) or (state = WR_MGT_SOF)) else
                                     tx_frame_cmd                    when ((state = RD_MGT_CMD ) or (state = WR_MGT_CMD)) else
                                     tx_crc                          when ((state = RD_MGT_CRC ) or (state = WR_MGT_CRC)) else
                                     (X"00" & K_IDL & X"00" & K_EOF) when ((state = RD_MGT_EOF ) or (state = WR_MGT_EOF)) else X"0000_0000";

   M00_AXIS_TVALID                <= tx_tvalid;
   M00_AXIS_TUSER                 <= tx_tuser;
   M00_AXIS_TDATA                 <= tx_tdata;

   -----------------------------------------------------------------------------
   -- AXI Read
   -----------------------------------------------------------------------------
   -- Address phase
   --M00_AXI_ARID                   <= (others => '0');
   m_araddr                       <=  rx_fifo_d_dout(31 downto  0)          when m_arburst = "00" else --ML84 change: avoid unaligned transfers
                                     (rx_fifo_d_dout(31 downto  2) & "00");
   M00_AXI_ARADDR                 <= m_araddr and RX_ADDR_MASK;
   m_arvalid                      <= '1' when (rx_fifo_d_e = '0') and (state = RD_AXI_ADDR) else '0';
   M00_AXI_ARVALID                <= m_arvalid;
   M00_AXI_ARSIZE                 <= "010";

   AXI_READ_PARAMS_P : process(AXI_ACLK)
   begin
      if rising_edge(AXI_ACLK) then
         if (state = HANDLE_DATA) then
            case rx_frame_opcode is
            when "1100" => -- PLB read single
               -- PLB SINGLE: len is 0, strobe is PLB_Size field
               m_arlen            <= X"00";
               m_arburst          <= rx_fifo_d_dout(29 downto 28);
            when "1110" => -- PLB read burst
               -- PLB BURST: len is PLB_Size field
               m_arlen            <= X"0" & rx_fifo_d_dout(26 downto 23);
               m_arburst          <= rx_fifo_d_dout(29 downto 28);
            when "0100" => -- AXI read single
               --AXI MODE: len is always lower byte
               m_arlen            <= rx_fifo_d_dout( 7 downto  0);
               m_arburst          <= rx_fifo_d_dout(29 downto 28);
            when "0110" => -- AXI read burst
               --AXI MODE: len is always lower byte
               m_arlen            <= rx_fifo_d_dout( 7 downto  0);
               m_arburst          <= rx_fifo_d_dout(29 downto 28);
            when others =>
               NULL; -- Unsupported opcode hence discard frame
            end case;
         end if;
      end if;
   end process;

   M00_AXI_ARLEN                  <= m_arlen;
   M00_AXI_ARBURST                <= m_arburst;

   -- Data phase
   m_rdata                        <= M00_AXI_RDATA;
   m_rready                       <= '1' when ((state = RD_MGT_DATA) and (M00_AXIS_TREADY = '1')) else '0';
   M00_AXI_RREADY                 <= m_rready;

   -----------------------------------------------------------------------------
   -- AXI Write
   -----------------------------------------------------------------------------
   -- Address phase
   --M00_AXI_AWID                   <= (others => '0');
   m_awaddr                       <=  rx_fifo_d_dout(31 downto  0)         when m_awburst = "00" else --ML84 change: avoid unaligned transfers
                                     (rx_fifo_d_dout(31 downto  2) & "00");
   M00_AXI_AWADDR                 <= m_awaddr and RX_ADDR_MASK;
   m_awvalid                      <= '1' when ((rx_fifo_d_e = '0') and (state = WR_AXI_ADDR)) else '0';
   M00_AXI_AWVALID                <= m_awvalid;
   M00_AXI_AWSIZE                 <= "010"; --only 32 bit supported

   AXI_WRITE_PARAMS_P : process(AXI_ACLK)
   begin
      if rising_edge(AXI_ACLK) then
         if (state = HANDLE_DATA) then
            case rx_frame_opcode is
            when "1000" => -- PLB write single
               -- PLB SINGLE: len is 0
               m_awlen            <= X"00";
               m_awburst          <= rx_fifo_d_dout(29 downto 28);
            when "1010" => -- PLB write burst
               -- PLB BURST: len is PLB_Size field
               m_awlen            <= X"0" & rx_fifo_d_dout(26 downto 23);
               m_awburst          <= rx_fifo_d_dout(29 downto 28);
            when "0000" => -- AXI write single
               --AXI MODE: len is always lower byte
               m_awlen            <= rx_fifo_d_dout( 7 downto  0);
               m_awburst          <= rx_fifo_d_dout(29 downto 28);
            when "0010" => -- AXI write burst
               --AXI MODE: len is always lower byte
               m_awlen            <= rx_fifo_d_dout( 7 downto  0);
               m_awburst          <= rx_fifo_d_dout(29 downto 28);
            when others =>
               NULL;
            end case;
         end if;
      end if;
   end process;

   M00_AXI_AWLEN                  <= m_awlen;
   M00_AXI_AWBURST                <= m_awburst;

   -- Data phase
   AXI_WRITE_COUNTER_P : process(AXI_ACLK)
   begin
      if rising_edge(AXI_ACLK) then
         if (AXI_ARESETN = '0') then
            m_awlen_cnt           <= (others => '0');
         else
            case state is
            when IDLE =>
               m_awlen_cnt        <= (others => '0');
            when WR_AXI_DATA =>
               if (rx_fifo_d_re = '1') then  -- data sampled, check/increment data counter
                  if (m_awlen_cnt < unsigned(m_awlen)) then
                     m_awlen_cnt  <= m_awlen_cnt + 1;
                  end if;
               end if;
            when others =>
               m_awlen_cnt        <= (others => '0');
            end case;
         end if;
      end if;
   end process;

   m_wdata                        <= rx_fifo_d_dout(31 downto 0);
   M00_AXI_WDATA                  <= m_wdata;
   m_wlast                        <= '1' when ((state = WR_AXI_DATA) and (m_awlen_cnt = unsigned(m_awlen))) else '0';
   M00_AXI_WLAST                  <= m_wlast;
   m_wvalid                       <= '1' when ((state = WR_AXI_DATA) and (rx_fifo_d_e = '0')) else '0';
   M00_AXI_WVALID                 <= m_wvalid;

   AXI_WRITE_STROBE_P : process(AXI_ACLK)
   begin
      if rising_edge(AXI_ACLK) then
         if (state = HANDLE_DATA) then
            case rx_frame_opcode is
            when "1000" => -- PLB write single
               m_wstrb            <= rx_fifo_d_dout(26 downto 23);
            when "1010" => -- PLB write burst
               m_wstrb            <= X"F";
            when "0000" => -- AXI write single
               m_wstrb            <= rx_fifo_d_dout(26 downto 23);
            when "0010" => -- AXI write burst
               m_wstrb            <= X"F";
            when others =>
               NULL;
            end case;
         end if;
      end if;
   end process;

   M00_AXI_WSTRB                  <= m_wstrb;

   m_bready                       <= '1' when (state = WR_AXI_ACK) else '0';
   --ML84 posted writes
   M00_AXI_BREADY                 <= '1' when POSTED_WRITES = '1' else
                                     m_bready and M00_AXIS_TREADY;

end architecture structural; --of axis_bridge_master_v1_0

--------------------------------------------------------------------------------
-- End of file
--------------------------------------------------------------------------------
