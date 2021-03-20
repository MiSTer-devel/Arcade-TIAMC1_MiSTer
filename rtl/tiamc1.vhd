--
-- 2021, Niels Lueddecke
--
-- All rights reserved.
--
-- Redistribution and use in source and synthezised forms, with or without modification, are permitted 
-- provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice, this list of conditions 
--    and the following disclaimer.
--
-- 2. Redistributions in synthezised form must reproduce the above copyright notice, this list of conditions
--    and the following disclaimer in the documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED 
-- WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A 
-- PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR 
-- ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
-- TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
-- NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
-- POSSIBILITY OF SUCH DAMAGE.
--

library IEEE;
use IEEE.std_logic_1164.all;

entity tiamc1 is
		generic (
			RESET_DELAY : integer := 100000
		);
		port(
		clk_sys				: in  std_logic;		-- 31,5Mhz
		clkLocked			: in  std_logic;
		reset_sig			: in  std_logic;
		
		joystick_0			: in  std_logic_vector(31 downto 0);
		joystick_analog_0	: in  std_logic_vector(15 downto 0);
		paddle_0				: in  std_logic_vector(7 downto 0);
		spinner_0			: in  std_logic_vector(8 downto 0);
		cfg_analog			: in  std_logic_vector(2 downto 0);
		
		scandouble			: in  std_logic;

		ce_pix				: out  std_logic;

		HBlank				: out std_logic;
		HSync					: out std_logic;
		VBlank				: out std_logic;
		VSync					: out std_logic;
		
		VGA_R					: out std_logic_vector(7 downto 0);
		VGA_G					: out std_logic_vector(7 downto 0);
		VGA_B					: out std_logic_vector(7 downto 0);
		
		clk_audio			: in  std_logic;		-- 24.576 MHz
		AUDIO_L				: out std_logic_vector(15 downto 0);
		AUDIO_R				: out std_logic_vector(15 downto 0);
		
		LED_USER				: out std_logic;
		LED_POWER			: out std_logic_vector(1 downto 0);
		LED_DISK				: out std_logic_vector(1 downto 0);
		
		USER_OUT				: out std_logic_vector(6 downto 0);
		
		dn_addr				: in std_logic_vector(19 downto 0);
		dn_data				: in std_logic_vector(7 downto 0);
		dn_wr					: in std_logic;
		tno					: in std_logic_vector(7 downto 0)
    );
end tiamc1;

architecture struct of tiamc1 is

	signal cpuReset_n			: std_logic;
	signal cpuAddr				: std_logic_vector(15 downto 0);
	signal cpuDataIn			: std_logic_vector(7 downto 0);
	signal cpuDataOut			: std_logic_vector(7 downto 0);
	signal cpuEn				: std_logic;
	signal cpuInt_n			: std_logic := '1';
	signal cpuWR_n				: std_logic;
	signal cpuRETI_n			: std_logic;
	signal cpuIntEna_n		: std_logic;
	
	signal cpuReady			: std_logic := '1';
	signal cpuHold				: std_logic := '0';
	signal cpuDBin				: std_logic;
	signal cpuSync				: std_logic;
	signal cpuWait				: std_logic;
	signal cpuHLDA				: std_logic;
	
	signal cpuStatus			: std_logic_vector(7 downto 0);
	signal cpuIntA				: std_logic;
	signal cpuWO_n				: std_logic;
	signal cpuHLTA				: std_logic;
	signal cpuOUT				: std_logic;
	signal cpuM1				: std_logic;
	signal cpuINP				: std_logic;
	signal cpuMEMR				: std_logic;
	
	signal tick_cpu			: std_logic;
	signal tick_vid			: std_logic;
	
	signal memDataOut			: std_logic_vector(7 downto 0);
	
	signal ioDataOut			: std_logic_vector(7 downto 0);
	
	signal resetDelay			: integer range 0 to RESET_DELAY := RESET_DELAY;
	
	signal ram_vid_adr		: std_logic_vector(10 downto 0);
	signal ram_vid_data		: std_logic_vector(7 downto 0);
	signal ram_char_adr		: std_logic_vector(10 downto 0);
	signal ram_char0_data	: std_logic_vector(7 downto 0);
	signal ram_char1_data	: std_logic_vector(7 downto 0);
	signal ram_char2_data	: std_logic_vector(7 downto 0);
	signal ram_char3_data	: std_logic_vector(7 downto 0);
	
	-- TEMP signals for watching
	signal HBlank_t			: std_logic;
	signal HSync_t				: std_logic;
	signal VBlank_t			: std_logic;
	signal VSync_t				: std_logic;
	signal TMP_DBG				: std_logic_vector(7 downto 0) := (others => '1');

begin

	-- reset
	cpuReset_n <= '0' when resetDelay /= 0 else '1';
	
	-- leds
	LED_USER  <= not cpuReset_n;
	LED_POWER <= b"11";
	LED_DISK  <= b"10";

	-- debug out
	--USER_OUT(6 downto 0) <= TMP_DBG(6 downto 0);
	USER_OUT <= b"1111111";

	-- sync
	HBlank <= HBlank_t;
	HSync  <= HSync_t;
	VBlank <= VBlank_t;
	VSync  <= VSync_t;

	reset : process
	begin
		wait until rising_edge(clk_sys);

		-- delay reset
		if resetDelay > 0 then -- Reset verzoegern?
			resetDelay <= resetDelay - 1;
		end if;

		-- begin reset
		if clkLocked = '0' or reset_sig = '1' then -- Reset
			resetDelay <= RESET_DELAY;
		end if;
	end process;

	-- video controller
	video : entity work.video
		port map (
			clk_sys		=> clk_sys, 
			tick_vid		=> tick_vid,
			reset_n 		=> cpuReset_n,
			
			ce_pix		=> ce_pix,
			
			vgaRed		=> VGA_R,
			vgaGreen		=> VGA_G,
			vgaBlue		=> VGA_B,
			vgaHSync		=> HSync_t,
			vgaVSync		=> VSync_t,
			vgaHBlank	=> HBlank_t,
			vgaVBlank	=> VBlank_t,

			cpuWR_n		=> cpuWR_n,
			cpuStatus	=> cpuStatus,
			cpuAddr		=> cpuAddr,
			cpuDIn		=> cpuDataOut,

			ram_vid_adr	   => ram_vid_adr,
			ram_vid_data   => ram_vid_data,
			ram_char_adr   => ram_char_adr,
			ram_char0_data => ram_char0_data,
			ram_char1_data => ram_char1_data,
			ram_char2_data => ram_char2_data,
			ram_char3_data => ram_char3_data,
			
			dn_addr		=> dn_addr,
			dn_data		=> dn_data,
			dn_wr			=> dn_wr,
			tno			=> tno
		);

	-- memory controller
	memcontrol : entity work.memcontrol
		port map (
			clk_sys		=> clk_sys,
			tick_cpu		=> tick_cpu,
			reset_n		=> cpuReset_n,

			cpuAddr		=> cpuAddr,
			cpuDOut		=> memDataOut,
			cpuDIn		=> cpuDataOut,

			cpuWR_n		=> cpuWR_n,
			
			cpuStatus	=> cpuStatus,
			cpuDBin		=> cpuDBin,

			cpuEn			=> cpuEn,
			
			ram_vid_adr    => ram_vid_adr,
			ram_vid_data   => ram_vid_data,
			ram_char_adr   => ram_char_adr,
			ram_char0_data => ram_char0_data,
			ram_char1_data => ram_char1_data,
			ram_char2_data => ram_char2_data,
			ram_char3_data => ram_char3_data,
			
			dn_addr		=> dn_addr,
			dn_data		=> dn_data,
			dn_wr			=> dn_wr,
			tno			=> tno
			
			--out_dbg		=> TMP_DBG
		);

	-- CPU data-in multiplexer
	cpuDataIn <= 
			ioDataOut		when cpuStatus = x"42" and cpuDBin = '1' else
			memDataOut;

	-- T8080 CPU
	cpu : entity work.T8080se
		generic map(Mode => 2, T2Write => 1)
		port map(
			RESET_n		=> cpuReset_n,
			CLK			=> clk_sys,
			CLKEN			=> cpuEn,
			--INT			=> cpuInt_n,
			INT			=> '0',
			IntE			=> cpuIntEna_n,
			RETI_n		=> cpuRETI_n,
			WR_n			=> cpuWR_n,
			A				=> cpuAddr,
			DI				=> cpuDataIn,
			DO				=> cpuDataOut,
			READY			=> cpuReady,
			HOLD			=> cpuHold,
			DBIN			=> cpuDBin,
			SYNC			=> cpuSync,
			VAIT			=> cpuWait,
			HLDA			=> cpuHLDA
		);
	
	-- get cpu status
	get_status : process
	begin
		wait until rising_edge(clk_sys);

		cpuReady <= '1';
		if cpuSync = '1' then
			cpuStatus <= cpuDataOut;
			cpuIntA  <= cpuDataOut(0);
			cpuWO_n  <= cpuDataOut(1);
			cpuHLTA  <= cpuDataOut(3);
			cpuOUT   <= cpuDataOut(4);
			cpuM1    <= cpuDataOut(5);
			cpuINP   <= cpuDataOut(6);
			cpuMEMR  <= cpuDataOut(7);
		end if;
	end process;
	
	-- system clocks/ticks
	sysclock : entity work.sysclock
		port map (
			clk_sys	=> clk_sys,
			reset_n	=> cpuReset_n,
			tick_cpu	=> tick_cpu,
			tick_vid	=> tick_vid
		);
	
	-- input ios and other
	inputs : entity work.inputs
		port map (
			clk_sys				=> clk_sys,
			reset_n				=> cpuReset_n,
			io_out				=> ioDataOut,
			cpuAddr				=> cpuAddr(7 downto 0),
			cpuStatus			=> cpuStatus,
			cpuDBin				=> cpuDBin,
			joystick_0			=> joystick_0,
			joystick_analog_0	=> joystick_analog_0,
			paddle_0				=> paddle_0,
			spinner_0			=> spinner_0,
			cfg_analog			=> cfg_analog,
			VBlank				=> VBlank_t,
			tno					=> tno
		);
		
	-- audio
	audio : entity work.audio
		port map (
			clk_sys		=> clk_sys,
			tick_cpu		=> tick_cpu,
			clk_audio	=> clk_audio,
			reset_n		=> cpuReset_n,
			AUDIO_L		=> AUDIO_L,
			AUDIO_R		=> AUDIO_R,
			
			cpuWR_n		=> cpuWR_n,
			cpuStatus	=> cpuStatus,
			cpuAddr		=> cpuAddr,
			cpuDIn		=> cpuDataOut,
			tno			=> tno,
			
			TMP_DBG		=> TMP_DBG
		);
end;
