--------------------------------------------------------------------------------
--                       Paul Scherrer Institute (PSI)
--------------------------------------------------------------------------------
-- Unit    : axi_master_tb.vhd
-- Author  : Goran Marinkovic, Section Diagnostic
-- Version : $Revision: 1.1 $
--------------------------------------------------------------------------------
-- Copyright© PSI, Section Diagnostic
--------------------------------------------------------------------------------
-- Comment : This is the test bench for the axi master including a standard
--           slave.
--------------------------------------------------------------------------------
-- Std. library (platform) -----------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_textio.all;
use ieee.std_logic_1164.all;

library std;
use std.textio.all;

-- Work library (application) --------------------------------------------------
use work.cdn_axi4_package.all;

entity axi_master_tb is
end entity;

architecture testbench of axi_master_tb is

   ---------------------------------------------------------------------------
   -- Signals
   ---------------------------------------------------------------------------
   -- System
   constant C_AXI_ACLK_CYCLE      : time:= 8 ns;
   -----------------------------------------------------------------------------
   -- MGT stream interface
   -----------------------------------------------------------------------------
   constant K_SOF                 : std_logic_vector( 7 downto  0) := X"FB"; -- K27.7
   constant K_SOF_DATA            : std_logic_vector(31 downto  0) := X"00" & K_SOF & X"0000";
   constant K_EOF                 : std_logic_vector( 7 downto  0) := X"FD"; -- K29.7
   constant K_EOF_DATA            : std_logic_vector(31 downto  0) := X"0000" & X"00" & K_EOF;
   signal   LEGACY_MODE           : std_logic := '0';
   -- AXI stream master (TX)
   signal   M00_AXIS_TREADY       : std_logic := '0';
   signal   M00_AXIS_TVALID       : std_logic := '0';
   signal   M00_AXIS_TUSER        : std_logic_vector( 3 downto  0) := (others => '0');
   signal   M00_AXIS_TDATA        : std_logic_vector(31 downto  0) := (others => '0');
   -- AXI stream slave (RX)
   signal   S00_AXIS_TREADY       : std_logic := '0';
   signal   S00_AXIS_TVALID       : std_logic := '0';
   signal   S00_AXIS_TUSER        : std_logic_vector( 3 downto  0) := (others => '0');
   signal   S00_AXIS_TDATA        : std_logic_vector(31 downto  0) := (others => '0');

   component axis_bridge_master_v1_0 is
   generic
   (
      --------------------------------------------------------------------------
      -- Stream
      --------------------------------------------------------------------------
      K_NOD                       : std_logic_vector( 7 downto  0) := X"7C"; -- K28.4
      K_SOF                       : std_logic_vector( 7 downto  0) := X"FB"; -- K27.7
      K_EOF                       : std_logic_vector( 7 downto  0) := X"FD"; -- K29.7
      K_ERR                       : std_logic_vector( 7 downto  0) := X"FE"; -- K30.7
      K_INT                       : std_logic_vector( 7 downto  0) := X"DC"; -- K28.6
      --------------------------------------------------------------------------
      -- AXI Master
      --------------------------------------------------------------------------
      RX_ADDR_MASK                : std_logic_vector(31 downto  0) := X"FFFF_FFFF" --this value is ANDed with the RX address
   );
   port
   (
      --------------------------------------------------------------------------
      -- Debug
      --------------------------------------------------------------------------
      debug_clk                   : out    std_logic;
      debug                       : out    std_logic_vector(127 downto  0);
      --------------------------------------------------------------------------
      -- System
      --------------------------------------------------------------------------
      AXI_ACLK                    : in    std_logic;
      AXI_ARESETN                 : in    std_logic;
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
      M00_AXI_AWADDR              : out   std_logic_vector(31 downto  0);
      M00_AXI_AWVALID             : out   std_logic;
      M00_AXI_AWREADY             : in    std_logic;
      M00_AXI_AWLEN               : out   std_logic_vector( 7 downto  0); -- NBEATS-1 (0=1 beat)
      M00_AXI_AWSIZE              : out   std_logic_vector( 2 downto  0); -- NBYTES=2^AWSIZE
      M00_AXI_AWBURST             : out   std_logic_vector( 1 downto  0); -- 00 fixed, 01 increment, 10 wrap
      -- Write Data
      M00_AXI_WDATA               : out   std_logic_vector(31 downto  0);
      M00_AXI_WSTRB               : out   std_logic_vector( 3 downto  0);
      M00_AXI_WLAST               : out   std_logic;
      M00_AXI_WVALID              : out   std_logic;
      M00_AXI_WREADY              : in    std_logic;
      -- Write response.
      M00_AXI_BRESP               : in    std_logic_vector( 1 downto  0);
      M00_AXI_BVALID              : in    std_logic;
      M00_AXI_BREADY              : out   std_logic;
      -- Read address.
      M00_AXI_ARADDR              : out   std_logic_vector(31 downto  0);
      M00_AXI_ARVALID             : out   std_logic;
      M00_AXI_ARREADY             : in    std_logic;
      M00_AXI_ARLEN               : out   std_logic_vector( 7 downto  0);
      M00_AXI_ARSIZE              : out   std_logic_vector( 2 downto  0);
      M00_AXI_ARBURST             : out   std_logic_vector( 1 downto  0);
      -- Read Data
      M00_AXI_RDATA               : in    std_logic_vector(31 downto  0);
      M00_AXI_RRESP               : in    std_logic_vector( 1 downto  0);
      M00_AXI_RLAST               : in    std_logic;
      M00_AXI_RVALID              : in    std_logic;
      M00_AXI_RREADY              : out   std_logic
   );
   end component axis_bridge_master_v1_0;

begin

   axis_bridge_master_v1_0_inst: axis_bridge_master_v1_0
   port map
   (
      --------------------------------------------------------------------------
      -- System
      --------------------------------------------------------------------------
      AXI_ACLK                    => ACLK,
      AXI_ARESETN                 => ARESETN,
      --------------------------------------------------------------------------
      -- MGT Stream Interface
      --------------------------------------------------------------------------
      LEGACY_MODE                 => LEGACY_MODE,
      --AXI Stream Master (TX)
      M00_AXIS_TREADY             => M00_AXIS_TREADY,
      M00_AXIS_TVALID             => M00_AXIS_TVALID,
      M00_AXIS_TUSER              => M00_AXIS_TUSER,
      M00_AXIS_TDATA              => M00_AXIS_TDATA,
      --AXI Stream Slave (RX)
      S00_AXIS_TREADY             => S00_AXIS_TREADY,
      S00_AXIS_TVALID             => S00_AXIS_TVALID,
      S00_AXIS_TUSER              => S00_AXIS_TUSER,
      S00_AXIS_TDATA              => S00_AXIS_TDATA,
      --------------------------------------------------------------------------
      -- AXI Master
      --------------------------------------------------------------------------
      -- Write Address
      M00_AXI_AWADDR              => AWADDR,
      M00_AXI_AWVALID             => AWVALID,
      M00_AXI_AWREADY             => AWREADY,
      M00_AXI_AWLEN               => AWLEN,
      M00_AXI_AWSIZE              => AWSIZE,
      M00_AXI_AWBURST             => AWBURST,
      -- Write Data
      M00_AXI_WDATA               => WDATA,
      M00_AXI_WSTRB               => WSTRB,
      M00_AXI_WLAST               => WLAST,
      M00_AXI_WVALID              => WVALID,
      M00_AXI_WREADY              => WREADY,
      -- Write response.
      M00_AXI_BRESP               => BRESP,
      M00_AXI_BVALID              => BVALID,
      M00_AXI_BREADY              => BREADY,
      -- Read address.
      M00_AXI_ARADDR              => ARADDR,
      M00_AXI_ARVALID             => ARVALID,
      M00_AXI_ARREADY             => ARREADY,
      M00_AXI_ARLEN               => ARLEN,
      M00_AXI_ARSIZE              => ARSIZE,
      M00_AXI_ARBURST             => ARBURST,
      -- Read Data
      M00_AXI_RDATA               => RDATA,
      M00_AXI_RRESP               => RRESP,
      M00_AXI_RLAST               => RLAST,
      M00_AXI_RVALID              => RVALID,
      M00_AXI_RREADY              => RREADY
   );

   axi_slave_inst: cdn_axi4_slave_bfm_wrap
   generic map
   (
      C_AXI_NAME                  => "SLAVE_test",

      C_AXI_MEMORY_MODEL_MODE     => 1,
      C_AXI_SLAVE_ADDRESS         => 0,
      C_AXI_SLAVE_MEM_SIZE        => 4096
   )
   port map
   (
      --------------------------------------------------------------------------
      -- AXI
      --------------------------------------------------------------------------
      -- System
      ACLK                        => ACLK,
      ARESETN                     => ARESETN,
      -- Write address channel
      AWID                        => AWID,
      AWADDR                      => AWADDR,
      AWVALID                     => AWVALID,
      AWREADY                     => AWREADY,
      AWLEN                       => AWLEN,
      AWSIZE                      => AWSIZE,
      AWBURST                     => AWBURST,
      AWLOCK                      => AWLOCK,
      AWCACHE                     => AWCACHE,
      AWPROT                      => AWPROT,
      AWREGION                    => AWREGION,
      AWQOS                       => AWQOS,
      AWUSER                      => AWUSER,
      --  Write data channel
      WDATA                       => WDATA,
      WLAST                       => WLAST,
      WVALID                      => WVALID,
      WREADY                      => WREADY,
      WSTRB                       => WSTRB,
      WUSER                       => WUSER,
      -- Write response channel
      BID                         => BID,
      BRESP                       => BRESP,
      BVALID                      => BVALID,
      BREADY                      => BREADY,
      BUSER                       => BUSER,
      -- Read address channel
      ARID                        => ARID,
      ARADDR                      => ARADDR,
      ARVALID                     => ARVALID,
      ARREADY                     => ARREADY,
      ARLEN                       => ARLEN,
      ARSIZE                      => ARSIZE,
      ARBURST                     => ARBURST,
      ARLOCK                      => ARLOCK,
      ARCACHE                     => ARCACHE,
      ARPROT                      => ARPROT,
      ARREGION                    => ARREGION,
      ARQOS                       => ARQOS,
      ARUSER                      => ARUSER,
      -- Read data channel
      RID                         => RID,
      RDATA                       => RDATA,
      RLAST                       => RLAST,
      RVALID                      => RVALID,
      RREADY                      => RREADY,
      RRESP                       => RRESP,
      RUSER                       => RUSER
   );

   -----------------------------------------------------------------------------
   -- AXI clock
   -----------------------------------------------------------------------------
   process
   begin
      loop
         ACLK                     <= '0';
         wait for C_AXI_ACLK_CYCLE / 2;
         ACLK                     <= '1';
         wait for C_AXI_ACLK_CYCLE / 2;
      end loop;
   end process;

   -----------------------------------------------------------------------------
   -- AXI reset
   -----------------------------------------------------------------------------
   process
   begin
      ARESETN                     <= '0';
      wait for 50 ns;
      wait until (rising_edge(ACLK));
      ARESETN                     <= '1';
      wait ;
   end process;

   -----------------------------------------------------------------------------
   -- Stimulus master AXI stream interface
   -----------------------------------------------------------------------------
   process
   begin
      -- Get out of reset
      wait until (ARESETN = '1');
      -- Test
      wait for 50 ns;
      M00_AXIS_TREADY             <= '1';
      wait;
   end process;

   -----------------------------------------------------------------------------
   -- Stimulus slave AXI stream interface
   -----------------------------------------------------------------------------
   process
   begin
      --------------------------------------------------------------------------
      -- Get out of reset
      --------------------------------------------------------------------------
      S00_AXIS_TVALID             <= '0';
      S00_AXIS_TUSER              <= "0000";
      S00_AXIS_TDATA              <= X"0000_0000";
      wait until (ARESETN = '1');
      --------------------------------------------------------------------------
      -- Test Write
      --------------------------------------------------------------------------
      wait for 50 ns;
      -- SOF
      wait until (ACLK = '1');
      S00_AXIS_TVALID             <= '1';
      S00_AXIS_TUSER              <= "0100";
      S00_AXIS_TDATA              <= K_SOF_DATA;
      wait until (ACLK = '1');
      -- CTRL
      S00_AXIS_TVALID             <= '1';
      S00_AXIS_TUSER              <= "0000";
      S00_AXIS_TDATA              <= X"0000_0000";
      S00_AXIS_TDATA(31)          <= '0'; -- READ/WRITE_n
      S00_AXIS_TDATA(28)          <= '1'; -- BURST/SINGLE_n
      S00_AXIS_TDATA( 8)          <= '0'; -- RESP (only if AXI MODE)
      S00_AXIS_TDATA( 7 downto  0)<= X"01"; -- ARLEN in AXI mode
      wait until (ACLK = '1');
      -- ADDR
      S00_AXIS_TVALID             <= '1';
      S00_AXIS_TUSER              <= "0000";
      S00_AXIS_TDATA              <= X"0000_0010";
      wait until (ACLK = '1');
      -- DATA 0
      S00_AXIS_TVALID             <= '1';
      S00_AXIS_TUSER              <= "0000";
      S00_AXIS_TDATA              <= X"BEAF_CACE";
      wait until (ACLK = '1');
      -- DATA 1
      S00_AXIS_TVALID             <= '1';
      S00_AXIS_TUSER              <= "0000";
      S00_AXIS_TDATA              <= X"DEAD_FACE";
      wait until (ACLK = '1');
      -- CRC
      S00_AXIS_TVALID             <= '1';
      S00_AXIS_TUSER              <= "0000";
      S00_AXIS_TDATA              <= X"5c04a76a";
      wait until (ACLK = '1');
      -- EOF
      S00_AXIS_TVALID             <= '1';
      S00_AXIS_TUSER              <= "0001";
      S00_AXIS_TDATA              <= K_EOF_DATA;
      wait until (ACLK = '1');
      S00_AXIS_TVALID             <= '0';
      S00_AXIS_TUSER              <= "0000";
      S00_AXIS_TDATA              <= X"0000_0000";
      --------------------------------------------------------------------------
      -- Test Read
      --------------------------------------------------------------------------
      wait for 50 ns;
      -- SOF
      wait until (ACLK = '1');
      S00_AXIS_TVALID             <= '1';
      S00_AXIS_TUSER              <= "0100";
      S00_AXIS_TDATA              <= K_SOF_DATA;
      wait until (ACLK = '1');
      -- CTRL
      S00_AXIS_TVALID             <= '1';
      S00_AXIS_TUSER              <= "0000";
      S00_AXIS_TDATA              <= X"0000_0000";
      S00_AXIS_TDATA(31)          <= '1'; -- READ/WRITE_n
      S00_AXIS_TDATA(28)          <= '1'; -- BURST/SINGLE_n
      S00_AXIS_TDATA( 8)          <= '0'; -- RESP (only if AXI MODE)
      S00_AXIS_TDATA( 7 downto  0)<= X"01"; -- ARLEN in AXI mode
      wait until (ACLK = '1');
      -- ADDR
      S00_AXIS_TVALID             <= '1';
      S00_AXIS_TUSER              <= "0000";
      S00_AXIS_TDATA              <= X"0000_0010";
      wait until (ACLK = '1');
      -- CRC
      S00_AXIS_TVALID             <= '1';
      S00_AXIS_TUSER              <= "0000";
      S00_AXIS_TDATA              <= X"4c52756a";
      wait until (ACLK = '1');
      -- EOF
      S00_AXIS_TVALID             <= '1';
      S00_AXIS_TUSER              <= "0001";
      S00_AXIS_TDATA              <= K_EOF_DATA;
      wait until (ACLK = '1');
      -- Finish simulation
      S00_AXIS_TVALID             <= '0';
      S00_AXIS_TUSER              <= "0000";
      S00_AXIS_TDATA              <= X"0000_0000";
      wait;
   end process;

end architecture testbench;
