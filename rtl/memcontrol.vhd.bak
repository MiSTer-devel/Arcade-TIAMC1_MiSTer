--
-- complete rewrite by Niels Lueddecke in 2021
--
-- Copyright (c) 2015, $ME
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
--
-- Speicher-Controller fuer KC85/4
--   fuer SRAM mit 256kx16
library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

entity memcontrol is
	port (
		clk			: in  std_logic;
		reset_n		: in  std_logic;

		cpuAddr		: in  std_logic_vector(15 downto 0);
		cpuDOut		: out std_logic_vector(7 downto 0);
		cpuDIn		: in  std_logic_vector(7 downto 0);

		cpuWR_n		: in  std_logic;
		cpuRD_n		: in  std_logic;
		cpuM1_n		: in  std_logic;
		cpuMREQ_n	: in  std_logic;
		cpuIORQ_n	: in  std_logic;

		cpuEn			: out std_logic;
		cpuWait		: out std_logic;

		cpuTick		: in  std_logic;

		umsr			: in  std_logic;
		afe			: in  std_logic;

		pioPortA		: in  std_logic_vector(7 downto 0);
		pioPortB		: in  std_logic_vector(7 downto 0);  
				 
		vidAddr		: in  std_logic_vector(13 downto 0);
		vidData		: out std_logic_vector(15 downto 0);
		vidRead		: out std_logic;
		vidBusy		: out std_logic;

		vidBlinkEn	: out std_logic;
		vidHires		: out std_logic
	);
end memcontrol;

architecture rtl of memcontrol is
	type   state_type is ( idle, idle_wait, do_idle, read_wait, do_read, write_wait, do_write, finish );
	signal mem_state    		: state_type := idle;
	
	signal tmp_adr				: std_logic_vector(15 downto 0);
	signal tmp_data_in		: std_logic_vector(7 downto 0);

	-- video read stuff
	signal vid_state			: std_logic_vector(1 downto 0) := (others => '0');
	signal vid_adr_old		: std_logic_vector(13 downto 0) := (others => '1');
	
	-- PIO
	signal port84				: std_logic_vector(7 downto 0);
	signal port86				: std_logic_vector(7 downto 0);

	-- ram 0
	signal ram0_do				: std_logic_vector(7 downto 0);
	signal ram0_we_n			: std_logic;

	-- ram 4
	signal ram4_do				: std_logic_vector(7 downto 0);
	signal ram4_we_n			: std_logic;

	-- ram 8 block 0
	signal ram8b0_do			: std_logic_vector(7 downto 0);
	signal ram8b0_we_n		: std_logic;

	-- ram 8 block 1
	signal ram8b1_do			: std_logic_vector(7 downto 0);
	signal ram8b1_we_n		: std_logic;

	-- ram IRM Pixel Bild 0 (Bildwiederholspeicher)
	signal irmPb0_do_1		: std_logic_vector(7 downto 0);
	signal irmPb0_wr_n_1		: std_logic;
	signal irmPb0_adr_2		: std_logic_vector(13 downto 0);
	signal irmPb0_do_2		: std_logic_vector(7 downto 0);

	-- ram IRM Color Bild 0 (Bildwiederholspeicher)
	signal irmCb0_do_1		: std_logic_vector(7 downto 0);
	signal irmCb0_wr_n_1		: std_logic;
	signal irmCb0_adr_2		: std_logic_vector(13 downto 0);
	signal irmCb0_do_2		: std_logic_vector(7 downto 0);

	-- ram IRM Pixel Bild 1 (Bildwiederholspeicher)
	signal irmPb1_do_1		: std_logic_vector(7 downto 0);
	signal irmPb1_wr_n_1		: std_logic;
	signal irmPb1_adr_2		: std_logic_vector(13 downto 0);
	signal irmPb1_do_2		: std_logic_vector(7 downto 0);

	-- ram IRM Color Bild 1 (Bildwiederholspeicher)
	signal irmCb1_do_1		: std_logic_vector(7 downto 0);
	signal irmCb1_wr_n_1		: std_logic;
	signal irmCb1_adr_2		: std_logic_vector(13 downto 0);
	signal irmCb1_do_2		: std_logic_vector(7 downto 0);
	
	-- rom
	signal rom_data    		: std_logic_vector(7 downto 0);
	signal romC_caos_data	: std_logic_vector(7 downto 0);
	signal romC_basic_data	: std_logic_vector(7 downto 0);
	signal romE_caos_data	: std_logic_vector(7 downto 0);
	signal romE_caos_adr		: std_logic_vector(12 downto 0);
	
	signal sig_dbg				: std_logic_vector(15 downto 0);
	
	-- memory control signals
	signal pioPortA_rdy		: std_logic := '0';
	signal ram0_en				: std_logic := '1';
	signal ram0_wp				: std_logic := '1';
	signal ram4_en				: std_logic := '0';
	signal ram4_wp				: std_logic := '0';
	signal ram8_en				: std_logic := '0';
	signal ram8_wp				: std_logic := '0';
	signal romC_caos_en		: std_logic := '0';
	signal romC_basic_en		: std_logic := '1';
	signal romE_caos_en		: std_logic := '1';
	signal irm					: std_logic := '1';

begin
	
	-- serve cpu
	cpuserv : process
	begin
		wait until rising_edge(clk);
		
		cpuWait	<= '1';
		cpuEn		<= '0';
		
		if reset_n = '0' then
			mem_state <= idle;
		end if;
		
		if pioPortA_rdy = '0' then
			romE_caos_en	<= '1';
			ram0_en			<= '1';
			irm				<= '1';
			ram0_wp			<= '1';
			romC_basic_en	<= '1';
		else
			romE_caos_en	<= pioPortA(0);
			ram0_en			<= pioPortA(1);
			irm				<= pioPortA(2);
			ram0_wp			<= pioPortA(3);
			romC_basic_en	<= pioPortA(7);
		end if;
		ram8_en			<= pioPortB(5);
		ram8_wp			<= pioPortB(6);
		ram4_en			<= port86(0);
		ram4_wp			<= port86(1);
		romC_caos_en	<= port86(7);
		
		-- memory state machine
		case mem_state is
			when idle =>
				if (reset_n='0') then
					port84 <= (others => '0');
					port86 <= (others => '0');
					romE_caos_adr <= afe & x"000";
					cpuDOut <= romE_caos_data;	-- ROM CAOS E reset vector
				elsif cpuTick = '1' then
					mem_state <= idle_wait;
					-- write to io port 84/86
					if		(cpuIORQ_n = '0' and cpuM1_n = '1' and cpuWR_n = '0') then
						case cpuAddr(7 downto 0) is
							when x"84"|x"85" => port84 <= cpuDIn;
							when x"86"|x"87" => port86 <= cpuDIn;
							when x"88" => pioPortA_rdy <= '1';
							when others => null;
						end case;
					-- write memory
					elsif (cpuMREQ_n = '0' and cpuWR_n = '0') then
						mem_state <= write_wait;
						tmp_adr <= cpuAddr;
						tmp_data_in <= cpuDIn;
						-- ram0/4 write decide which WR_en to strobe
						if		cpuAddr(15 downto 14) = b"00" and ram0_en = '1' and ram0_wp = '1' then ram0_we_n  <= '0';	-- ram0
						elsif	cpuAddr(15 downto 14) = b"01" and ram4_en = '1' and ram4_wp = '1' then ram4_we_n  <= '0';	-- ram4
						elsif cpuAddr(15 downto 14) = b"10" and irm = '0' then
							-- ram8 write decide which WR_en to strobe
							if		ram8_en = '1' and ram8_wp = '1' and port84(4) = '0' then ram8b0_we_n <= '0';	-- ram8 bank 0
							elsif	ram8_en = '1' and ram8_wp = '1' and port84(4) = '1' then ram8b1_we_n <= '0';	-- ram8 bank 1
							end if;
						elsif cpuAddr(15 downto 14) = b"10" and irm = '1' then
							-- Bildspeicher/systemspeicher
							if cpuAddr < x"a800" then
								-- irm write decide which WR_en to strobe
								if		port84(1) = '1' and port84(2) = '0' then irmCb0_wr_n_1 <= '0';		-- Bild 0, Color
								elsif	port84(1) = '0' and port84(2) = '0' then irmPb0_wr_n_1 <= '0';		-- Bild 0, Pixel
								elsif	port84(1) = '1' and port84(2) = '1' then irmCb1_wr_n_1 <= '0';		-- Bild 1, Color
								elsif	port84(1) = '0' and port84(2) = '1' then irmPb1_wr_n_1 <= '0';		-- Bild 1, Pixel
								end if;
							else
								-- systemspeicher in Bild0/Pixel
								irmPb0_wr_n_1 <= '0';
							end if;
						end if;
					-- read memory
					elsif (cpuMREQ_n='0' and cpuRD_n='0') then
						mem_state <= read_wait;
						tmp_adr <= cpuAddr;
						if umsr = '0' then
							-- boot, modify cpu address to point to caos romE, afe differ between poweron and reset button
							romE_caos_adr <= afe & x"0" & cpuAddr(7 downto 0);
						else
							-- normal operation, pass cpu address to caos romE unmodified
							romE_caos_adr <= cpuAddr(12 downto 0);
						end if;
					end if;
				end if;
			when read_wait =>
				mem_state <= do_read;
			when do_read =>
				mem_state <= finish;
				-- decide which DO to send to cpu
				if umsr = '0' then
					-- startup, pass caos romE data to cpu
					cpuDOut <= romE_caos_data;
				else
					-- after startup, decide which DO to send to cpu
					if		tmp_adr(15 downto 14) = b"00"  and ram0_en       = '1' then cpuDOut <= ram0_do;				-- ram0
					elsif	tmp_adr(15 downto 14) = b"01"  and ram4_en       = '1' then cpuDOut <= ram4_do;				-- ram4
					elsif	tmp_adr(15 downto 13) = b"110" and romC_basic_en = '1' then cpuDOut <= romC_basic_data;	-- ROM BASIC
					elsif	tmp_adr(15 downto 13) = b"110" and romC_caos_en  = '1' then cpuDOut <= romC_caos_data;		-- ROM CAOS C
					elsif	tmp_adr(15 downto 13) = b"111" and romE_caos_en  = '1' then cpuDOut <= romE_caos_data;		-- ROM CAOS E
					elsif tmp_adr(15 downto 14) = b"10"  and irm = '0' then
						-- ram read decide what DO to send
						if		ram8_en = '1' and port84(4) = '0' then cpuDOut <= ram8b0_do;		-- ram8 bank 0
						elsif	ram8_en = '1' and port84(4) = '1' then cpuDOut <= ram8b1_do;		-- ram8 bank 1
						end if;
					elsif tmp_adr(15 downto 14) = b"10"  and irm = '1' then
						-- Bildspeicher/systemspeicher in Bild0/Pixel
						if tmp_adr < x"a800" then
							-- irm read decide what DO to send
							if		port84(1)   = '1' and port84(2) = '0' then cpuDOut <= irmCb0_do_1;	-- Bild 0, Color
							elsif	port84(1)   = '0' and port84(2) = '0' then cpuDOut <= irmPb0_do_1;	-- Bild 0, Pixel
							elsif	port84(1)   = '1' and port84(2) = '1' then cpuDOut <= irmCb1_do_1;	-- Bild 1, Color
							elsif	port84(1)   = '0' and port84(2) = '1' then cpuDOut <= irmPb1_do_1;	-- Bild 1, Pixel
							end if;
						else
							-- systemspeicher in Bild0/Pixel
							cpuDOut <= irmPb0_do_1;
						end if;
					end if;
				end if;
			when write_wait =>
				mem_state <= do_write;
			when do_write =>
				mem_state <= finish;
				ram0_we_n     <= '1';
				ram4_we_n     <= '1';
				ram8b0_we_n   <= '1';
				ram8b1_we_n   <= '1';
				irmPb0_wr_n_1 <= '1';
				irmCb0_wr_n_1 <= '1';
				irmPb1_wr_n_1 <= '1';
				irmCb1_wr_n_1 <= '1';
				cpuDOut <= tmp_data_in;
			when idle_wait =>
				mem_state <= do_idle;
			when do_idle =>
				mem_state <= finish;
			when finish =>
				mem_state <= idle;
				cpuEn		<= '1';
			end case;
	end process;
	
	-- serve video
	vidBusy <= '0';
	vidserv : process
	begin
		wait until rising_edge(clk);
		
		vidRead <= '0';
		case vid_state is
			when b"00" =>
				irmPb0_adr_2 <= vidAddr;
				irmCb0_adr_2 <= vidAddr;
				irmPb1_adr_2 <= vidAddr;
				irmCb1_adr_2 <= vidAddr;
				if (vid_adr_old /= vidAddr) then
					vid_state	 <= b"01";
				end if;
			when b"01" =>
				vid_state <= b"10";
			when b"10" =>
				vid_state <= b"11";
			when b"11" =>
				vid_state <= b"00";
				vidRead	 <= '1';
				vid_adr_old  <= vidAddr;
				-- real video
				if	port84(0) = '0' then
					vidData <= irmCb0_do_2 & irmPb0_do_2;	-- Bild 0
				else
					vidData <= irmCb1_do_2 & irmPb1_do_2;	-- Bild 1
				end if;
		end case;
		vidBlinkEn <= pioPortB(7);
		vidHires  <= not port84(3);
	end process;
	 
	-- ram0
	sram_ram0 : entity work.sram
		generic map (
			AddrWidth => 14,
			DataWidth => 8
		)
		port map (
			clk  => clk,
			addr => tmp_adr(13 downto 0),
			din  => tmp_data_in,
			dout => ram0_do,
			ce_n => '0', 
			we_n => ram0_we_n
		);
		
	-- ram4
	sram_ram4 : entity work.sram
		generic map (
			AddrWidth => 14,
			DataWidth => 8
		)
		port map (
			clk  => clk,
			addr => tmp_adr(13 downto 0),
			din  => tmp_data_in,
			dout => ram4_do,
			ce_n => '0', 
			we_n => ram4_we_n
		);

	-- ram8b0
	sram_ram8b0 : entity work.sram
		generic map (
			AddrWidth => 14,
			DataWidth => 8
		)
		port map (
			clk  => clk,
			addr => tmp_adr(13 downto 0),
			din  => tmp_data_in,
			dout => ram8b0_do,
			ce_n => '0', 
			we_n => ram8b0_we_n
		);
		
	-- ram8b1
	sram_ram8b1 : entity work.sram
		generic map (
			AddrWidth => 14,
			DataWidth => 8
		)
		port map (
			clk  => clk,
			addr => tmp_adr(13 downto 0),
			din  => tmp_data_in,
			dout => ram8b1_do,
			ce_n => '0', 
			we_n => ram8b1_we_n
		);
	
	-- irmPb0
	irmPb0 : entity work.dualsram
		generic map (
			AddrWidth => 14
		)
		port map (
			clk1  => clk,
			addr1 => tmp_adr(13 downto 0),
			din1  => tmp_data_in,
			dout1 => irmPb0_do_1,
			cs1_n => '0', 
			wr1_n => irmPb0_wr_n_1,

			clk2  => clk,
			addr2 => irmPb0_adr_2,
			din2  => (others => '0'),
			dout2 => irmPb0_do_2,
			cs2_n => '0',
			wr2_n => '1'
		);
		
	-- irmCb0
	irmCb0 : entity work.dualsram
		generic map (
			AddrWidth => 14
		)
		port map (
			clk1  => clk,
			addr1 => tmp_adr(13 downto 0),
			din1  => tmp_data_in,
			dout1 => irmCb0_do_1,
			cs1_n => '0', 
			wr1_n => irmCb0_wr_n_1,

			clk2  => clk,
			addr2 => irmCb0_adr_2,
			din2  => (others => '0'),
			dout2 => irmCb0_do_2,
			cs2_n => '0',
			wr2_n => '1'
		);
		
	-- irmPb1
	irmPb1 : entity work.dualsram
		generic map (
			AddrWidth => 14
		)
		port map (
			clk1  => clk,
			addr1 => tmp_adr(13 downto 0),
			din1  => tmp_data_in,
			dout1 => irmPb1_do_1,
			cs1_n => '0', 
			wr1_n => irmPb1_wr_n_1,

			clk2  => clk,
			addr2 => irmPb1_adr_2,
			din2  => (others => '0'),
			dout2 => irmPb1_do_2,
			cs2_n => '0',
			wr2_n => '1'
		);
		
	-- irmCb1
	irmCb1 : entity work.dualsram
		generic map (
			AddrWidth => 14
		)
		port map (
			clk1  => clk,
			addr1 => tmp_adr(13 downto 0),
			din1  => tmp_data_in,
			dout1 => irmCb1_do_1,
			cs1_n => '0', 
			wr1_n => irmCb1_wr_n_1,

			clk2  => clk,
			addr2 => irmCb1_adr_2,
			din2  => (others => '0'),
			dout2 => irmCb1_do_2,
			cs2_n => '0',
			wr2_n => '1'
		);
	
	-- caos c
	caos_c : entity work.caos_c
		port map (
			clk => clk,
			addr => tmp_adr(11 downto 0),
			data => romC_caos_data
		);
	
	-- basic c
	basic : entity work.basic
		port map (
			clk => clk,
			addr => tmp_adr(12 downto 0),
			data => romC_basic_data
		);

	-- caos e
	caos_e : entity work.caos_e
		port map (
			clk => clk,
			addr => romE_caos_adr,
			data => romE_caos_data
		);
end;
