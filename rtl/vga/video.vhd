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
use IEEE.numeric_std.all;

entity video is
    port (
			clk_sys			: in  std_logic;
			tick_vid			: in  std_logic;
			reset_n			: in  std_logic;
			
			ce_pix			: out std_logic;

			vgaRed			: out std_logic_vector(7 downto 0);
			vgaGreen			: out std_logic_vector(7 downto 0);
			vgaBlue			: out std_logic_vector(7 downto 0);
			vgaHSync			: out std_logic;
			vgaVSync			: out std_logic;
			vgaHBlank		: out std_logic;
			vgaVBlank		: out std_logic;
			
			cpuWR_n			: in  std_logic;
			cpuStatus		: in  std_logic_vector(7 downto 0);
			cpuAddr			: in  std_logic_vector(15 downto 0);
			cpuDIn			: in  std_logic_vector(7 downto 0);
			
			ram_vid_adr		: out std_logic_vector(10 downto 0);
			ram_vid_data	: in  std_logic_vector(7 downto 0);
			ram_char_adr	: out std_logic_vector(10 downto 0);
			ram_char0_data	: in  std_logic_vector(7 downto 0);
			ram_char1_data	: in  std_logic_vector(7 downto 0);
			ram_char2_data	: in  std_logic_vector(7 downto 0);
			ram_char3_data	: in  std_logic_vector(7 downto 0);
			
			dn_addr			: in std_logic_vector(19 downto 0);
			dn_data			: in std_logic_vector(7 downto 0);
			dn_wr				: in std_logic;
			tno				: in std_logic_vector(7 downto 0)
			);
end video;

architecture rtl of video is
	-- vid constants
	constant H_SYNC_ACTIVE	: std_logic := '1';
	constant H_BLANK_ACTIVE	: std_logic := '1';
	constant V_SYNC_ACTIVE	: std_logic := '1';
	constant V_BLANK_ACTIVE	: std_logic := '1';
	-- array types
	type PaletType is array(15 downto 0) of std_logic_vector(23 downto 0);
	type SpColorType is array(15 downto 0) of std_logic_vector(3 downto 0);
	-- palette array
	signal palette			: PaletType := (others => (others => '0'));
	-- sprite components
	signal sp_en_n      	: std_logic_vector(15 downto 0);
	signal sp_update		: std_logic_vector(7 downto 0);
	signal sp_draw_pixel	: std_logic;
	signal sp_screen_x	: unsigned(7 downto 0);
	signal sp_screen_y	: unsigned(7 downto 0);
	signal sp_pos_x		: unsigned(7 downto 0);
	signal sp_pos_y		: unsigned(7 downto 0);
	signal sp_nr			: std_logic_vector(7 downto 0);
	signal sp_attrib		: std_logic_vector(7 downto 0);
	signal sp_color		: SpColorType := (others => (others => '0'));
	signal sp_cnt_feed	: unsigned(7 downto 0) := (others => '1');
	signal sp_ptr			: std_logic_vector(3 downto 0);
	signal sp_data_adr	: std_logic_vector(7 downto 0);

	-- pipeline register
	type reg is record
		do_stuff				: std_logic;
		cnt_h					: unsigned(11 downto 0);
		cnt_v					: unsigned(11 downto 0);
		pos_x					: unsigned(11 downto 0);
		pos_y					: unsigned(11 downto 0);
		sync_h				: std_logic;
		sync_v				: std_logic;
		blank_h				: std_logic;
		blank_v				: std_logic;
		color_ch				: std_logic_vector(3 downto 0);
		color_sp				: std_logic_vector(3 downto 0);
	end record;

	signal s0 : reg := ('0', (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), '0', '0', '0', '0', (others=>'0'), (others=>'0'));
	signal s1 : reg := ('0', (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), '0', '0', '0', '0', (others=>'0'), (others=>'0'));
	signal s2 : reg := ('0', (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), '0', '0', '0', '0', (others=>'0'), (others=>'0'));
	signal s3 : reg := ('0', (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), '0', '0', '0', '0', (others=>'0'), (others=>'0'));
	signal s4 : reg := ('0', (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), '0', '0', '0', '0', (others=>'0'), (others=>'0'));
	signal s5 : reg := ('0', (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), '0', '0', '0', '0', (others=>'0'), (others=>'0'));
	signal s6 : reg := ('0', (others=>'0'), (others=>'0'), (others=>'0'), (others=>'0'), '0', '0', '0', '0', (others=>'0'), (others=>'0'));

	-- counter
	signal cnt_h			: unsigned(11 downto 0) := (others => '0');
	signal cnt_v			: unsigned(11 downto 0) := (others => '0');

	-- sprite roms
	signal sprom_adr			: std_logic_vector(12 downto 0);
	signal sprom_adr_fin		: std_logic_vector(12 downto 0);
	signal sprom_a2_data 	: std_logic_vector(7 downto 0);
	signal sprom_a2_we_n		: std_logic;
	signal sprom_a3_data 	: std_logic_vector(7 downto 0);
	signal sprom_a3_we_n		: std_logic;
	signal sprom_a5_data 	: std_logic_vector(7 downto 0);
	signal sprom_a5_we_n		: std_logic;
	signal sprom_a6_data 	: std_logic_vector(7 downto 0);
	signal sprom_a6_we_n		: std_logic;
	signal sprom_data_in		: std_logic_vector(7 downto 0);
	
	-- tile roms
	signal trom_adr			: std_logic_vector(12 downto 0);
	signal trom_adr_fin		: std_logic_vector(12 downto 0);
	signal trom_1_data 		: std_logic_vector(7 downto 0);
	signal trom_1_we_n		: std_logic;
	signal trom_2_data 		: std_logic_vector(7 downto 0);
	signal trom_2_we_n		: std_logic;
	signal trom_3_data 		: std_logic_vector(7 downto 0);
	signal trom_3_we_n		: std_logic;
	signal trom_4_data 		: std_logic_vector(7 downto 0);
	signal trom_4_we_n		: std_logic;
	signal trom_data_in		: std_logic_vector(7 downto 0);
	signal trom_ctrl		  	: std_logic_vector(7 downto 0);
	
	-- palette stuff
	signal palrom_adr		: std_logic_vector(7 downto 0);
	signal palrom_data	: std_logic_vector(23 downto 0);
	signal tmp_pal_nr		: std_logic_vector(3 downto 0);
	signal tmp_pal_cnt	: unsigned(3 downto 0);

begin
	vid_gen : process 
	begin
		wait until rising_edge(clk_sys);
		
		-- defaults
		s0.do_stuff   <= '0';
		sp_en_n       <= (others => '1');
		sp_draw_pixel <= '0';
		
		-- io writes
		if cpuStatus = x"10" and cpuWR_n = '0' then
			-- palette
			if		(tno(7) = '0' and cpuAddr(7 downto 4) = x"a") or (tno(7) = '1' and cpuAddr(7 downto 4) = x"e") then
				tmp_pal_nr	<= cpuAddr(3 downto 0);
				tmp_pal_cnt	<= x"3";
				palrom_adr	<= cpuDIn;
			-- sprite position y
			elsif	(tno(7) = '0' and cpuAddr(7 downto 4) = x"4") or (tno(7) = '1' and cpuAddr(7 downto 4) = x"0") then
				sp_en_n(to_integer(unsigned(cpuAddr(3 downto 0)))) <= '0';
				sp_update	<= x"01";
				sp_pos_y		<= unsigned(cpuDIn xor x"ff");
			-- sprite position x
			elsif	(tno(7) = '0' and cpuAddr(7 downto 4) = x"5") or (tno(7) = '1' and cpuAddr(7 downto 4) = x"1") then
				sp_en_n(to_integer(unsigned(cpuAddr(3 downto 0)))) <= '0';
				sp_update	<= x"02";
				sp_pos_x		<= unsigned(cpuDIn xor x"ff");
			-- sprite number
			elsif	(tno(7) = '0' and cpuAddr(7 downto 4) = x"6") or (tno(7) = '1' and cpuAddr(7 downto 4) = x"2") then
				sp_nr     	<= cpuDIn xor x"ff";
				sp_ptr		<= cpuAddr(3 downto 0);
				sp_cnt_feed	<= x"00";
			-- sprite attributes
			elsif	(tno(7) = '0' and cpuAddr(7 downto 4) = x"7") or (tno(7) = '1' and cpuAddr(7 downto 4) = x"3") then
				sp_en_n(to_integer(unsigned(cpuAddr(3 downto 0)))) <= '0';
				sp_update	<= x"08";
				sp_attrib	<= cpuDIn;
			-- v2 hardware: tile rom bank switch control
			elsif	tno(7) = '1' and cpuAddr(7 downto 0) = x"f8" then
				trom_ctrl	<= cpuDIn;
			end if;
		end if;
		
		-- copy color from palette rom
		if tmp_pal_cnt > 0 then
			tmp_pal_cnt <= tmp_pal_cnt - 1;
			if tmp_pal_cnt = 1 then
				palette(to_integer(unsigned(tmp_pal_nr))) <= palrom_data;
			end if;
		end if;
		
		-- copy sprite data to sprite component
		if sp_cnt_feed < 64 then
			sp_cnt_feed <= sp_cnt_feed + 1;
			if sp_cnt_feed(0) = '0' then
				-- set sprite rom address
				sprom_adr <= sp_cnt_feed(1) & sp_nr & std_logic_vector(sp_cnt_feed(5 downto 2));
			else
				-- shove data into sprite component
				sp_en_n(to_integer(unsigned(sp_ptr))) <= '0';
				sp_update	<= x"20";
				sp_data_adr	<= b"0" & std_logic_vector(sp_cnt_feed(7 downto 1));
			end if;
		end if;
		
		-- reset
		if reset_n = '0' then
			--cnt_h	    <= (others => '0');
			--cnt_v     <= (others => '0');
		else
			-- tick vid
			if tick_vid = '1' then
				-- hsync counter
				if cnt_h < 336 then
					cnt_h <= cnt_h + 1;
				else
					cnt_h <= x"000";
					-- vsync counter
					if cnt_v < 312 then
						cnt_v <= cnt_v + 1;
					else
						cnt_v <= x"000";
					end if;
				end if;
				-- fill pipeline
				s0.do_stuff <= '1';
				s0.cnt_h    <= cnt_h;
				s0.cnt_v    <= cnt_v;
				s0.sync_h   <= not H_SYNC_ACTIVE;
				s0.sync_v   <= not V_SYNC_ACTIVE;
				s0.blank_h  <= H_BLANK_ACTIVE;
				s0.blank_v  <= V_BLANK_ACTIVE;
			end if;
		end if;
		
		-- work the pipe
		-- stage 0
		s1 <= s0;
		if s0.do_stuff = '1' then
			s1.pos_x <= s0.cnt_h - 66; -- too far
			s1.pos_y <= s0.cnt_v - 6;
			-- horizontal sync
			if s0.cnt_h < 40 then		-- B&O syncs ok
				s1.sync_h <= H_SYNC_ACTIVE;
			end if;
			-- vertical sync
			if s0.cnt_v > 280 and s0.cnt_v < 284 then		-- seems ok? B&O seems to like it
				s1.sync_v <= V_SYNC_ACTIVE;
			end if;
		end if;
		-- stage 1
		s2 <= s1;
		if s1.do_stuff = '1' then
			-- blank signals
			if s1.pos_x < 256 then
				s2.blank_h <= not H_BLANK_ACTIVE;
			end if;
			if s1.pos_y < 256 then
				s2.blank_v <= not V_BLANK_ACTIVE;
			end if;
			-- set video ram address, fetch tile nr, 10:0
			ram_vid_adr <= std_logic_vector(b"0" & s1.pos_y(7 downto 3) & s1.pos_x(7 downto 3));
			-- update sprite components with current screen position and draw pixel
			sp_draw_pixel <= '1';
			sp_screen_x   <= s1.pos_x(7 downto 0);
			sp_screen_y   <= s1.pos_y(7 downto 0);
		end if;
		-- stage 2
		s3 <= s2;
		-- stage 3
		s4 <= s3;
		if s3.do_stuff = '1' then
			-- set address in char ram
			if tno(7) = '0' then
				-- v1 hardware
				ram_char_adr <= ram_vid_data & std_logic_vector(s3.pos_y(2 downto 0));
			else
				-- v2 hardware
				trom_adr <= trom_ctrl(5 downto 4) & ram_vid_data & std_logic_vector(s3.pos_y(2 downto 0));
			end if;
		end if;
		-- stage 4
		s5 <= s4;
		-- stage 5
		s6 <= s5;
		if s5.do_stuff = '1' then
			-- chars / tiles
			if tno(7) = '0' then
				-- v1 hardware
				if		s5.pos_x(2 downto 0) = b"000" then s6.color_ch <= ram_char3_data(7) & ram_char2_data(7) & ram_char1_data(7) & ram_char0_data(7);
				elsif	s5.pos_x(2 downto 0) = b"001" then s6.color_ch <= ram_char3_data(6) & ram_char2_data(6) & ram_char1_data(6) & ram_char0_data(6);
				elsif	s5.pos_x(2 downto 0) = b"010" then s6.color_ch <= ram_char3_data(5) & ram_char2_data(5) & ram_char1_data(5) & ram_char0_data(5);
				elsif	s5.pos_x(2 downto 0) = b"011" then s6.color_ch <= ram_char3_data(4) & ram_char2_data(4) & ram_char1_data(4) & ram_char0_data(4);
				elsif	s5.pos_x(2 downto 0) = b"100" then s6.color_ch <= ram_char3_data(3) & ram_char2_data(3) & ram_char1_data(3) & ram_char0_data(3);
				elsif	s5.pos_x(2 downto 0) = b"101" then s6.color_ch <= ram_char3_data(2) & ram_char2_data(2) & ram_char1_data(2) & ram_char0_data(2);
				elsif	s5.pos_x(2 downto 0) = b"110" then s6.color_ch <= ram_char3_data(1) & ram_char2_data(1) & ram_char1_data(1) & ram_char0_data(1);
				elsif	s5.pos_x(2 downto 0) = b"111" then s6.color_ch <= ram_char3_data(0) & ram_char2_data(0) & ram_char1_data(0) & ram_char0_data(0);
				end if;
			else
				-- v2 hardware
				if		s5.pos_x(2 downto 0) = b"000" then s6.color_ch <= trom_4_data(7) & trom_3_data(7) & trom_2_data(7) & trom_1_data(7);
				elsif	s5.pos_x(2 downto 0) = b"001" then s6.color_ch <= trom_4_data(6) & trom_3_data(6) & trom_2_data(6) & trom_1_data(6);
				elsif	s5.pos_x(2 downto 0) = b"010" then s6.color_ch <= trom_4_data(5) & trom_3_data(5) & trom_2_data(5) & trom_1_data(5);
				elsif	s5.pos_x(2 downto 0) = b"011" then s6.color_ch <= trom_4_data(4) & trom_3_data(4) & trom_2_data(4) & trom_1_data(4);
				elsif	s5.pos_x(2 downto 0) = b"100" then s6.color_ch <= trom_4_data(3) & trom_3_data(3) & trom_2_data(3) & trom_1_data(3);
				elsif	s5.pos_x(2 downto 0) = b"101" then s6.color_ch <= trom_4_data(2) & trom_3_data(2) & trom_2_data(2) & trom_1_data(2);
				elsif	s5.pos_x(2 downto 0) = b"110" then s6.color_ch <= trom_4_data(1) & trom_3_data(1) & trom_2_data(1) & trom_1_data(1);
				elsif	s5.pos_x(2 downto 0) = b"111" then s6.color_ch <= trom_4_data(0) & trom_3_data(0) & trom_2_data(0) & trom_1_data(0);
				end if;

			end if;
			-- sprites
			if		sp_color(0)  /= x"f" then s6.color_sp <= sp_color(0);
			elsif sp_color(1)  /= x"f" then s6.color_sp <= sp_color(1);
			elsif sp_color(2)  /= x"f" then s6.color_sp <= sp_color(2);
			elsif sp_color(3)  /= x"f" then s6.color_sp <= sp_color(3);
			elsif sp_color(4)  /= x"f" then s6.color_sp <= sp_color(4);
			elsif sp_color(5)  /= x"f" then s6.color_sp <= sp_color(5);
			elsif sp_color(6)  /= x"f" then s6.color_sp <= sp_color(6);
			elsif sp_color(7)  /= x"f" then s6.color_sp <= sp_color(7);
			elsif sp_color(8)  /= x"f" then s6.color_sp <= sp_color(8);
			elsif sp_color(9)  /= x"f" then s6.color_sp <= sp_color(9);
			elsif sp_color(10) /= x"f" then s6.color_sp <= sp_color(10);
			elsif sp_color(11) /= x"f" then s6.color_sp <= sp_color(11);
			elsif sp_color(12) /= x"f" then s6.color_sp <= sp_color(12);
			elsif sp_color(13) /= x"f" then s6.color_sp <= sp_color(13);
			elsif sp_color(14) /= x"f" then s6.color_sp <= sp_color(14);
			elsif sp_color(15) /= x"f" then s6.color_sp <= sp_color(15);
			else s6.color_sp <= x"f";
			end if;
		end if;
		-- stage 6
		if s6.do_stuff = '1' then
			if s6.blank_h /= H_BLANK_ACTIVE and s6.blank_v /= V_BLANK_ACTIVE then
				if s6.color_sp /= x"f" then
					-- draw sprite
					vgaRed    <= palette(to_integer(unsigned(s6.color_sp)))(23 downto 16);
					vgaGreen  <= palette(to_integer(unsigned(s6.color_sp)))(15 downto 8);
					vgaBlue   <= palette(to_integer(unsigned(s6.color_sp)))(7 downto 0);
				else
					-- draw char
					vgaRed    <= palette(to_integer(unsigned(s6.color_ch)))(23 downto 16);
					vgaGreen  <= palette(to_integer(unsigned(s6.color_ch)))(15 downto 8);
					vgaBlue   <= palette(to_integer(unsigned(s6.color_ch)))(7 downto 0);
				end if;
			else	-- B&O likes it
				vgaRed   <= x"00";
				vgaGreen <= x"00";
				vgaBlue  <= x"00";
			end if;
			vgaHSync  <= s6.sync_h;
			vgaVSync  <= s6.sync_v;
			vgaHBlank <= s6.blank_h;
			vgaVBlank <= s6.blank_v;
		end if;
		-- turn on/off video output
		ce_pix <= s6.do_stuff;
	end process;
	
	-- sprite components
	sprites: for i in 0 to 15 generate
        sprite : entity work.sprite
        port map (
            clk				=> clk_sys,
            reset_n 			=> reset_n,
            en_n				=> sp_en_n(i),
				in_update		=> sp_update,
				in_draw_pixel	=> sp_draw_pixel,
				
				in_screen_x		=> sp_screen_x,
				in_screen_y		=> sp_screen_y,
				
				in_pos_x			=> sp_pos_x,
				in_pos_y			=> sp_pos_y,
				in_attrib		=> sp_attrib,
				
				out_color		=> sp_color(i),
				
				in_data_a		=> sprom_a2_data,
				in_data_b		=> sprom_a3_data,
				in_data_c		=> sprom_a5_data,
				in_data_d		=> sprom_a6_data,
				in_data_adr		=> sp_data_adr
        );
	end generate;
	
	-- fill sprite rom
	sprom_a2_we_n <=	'0' when dn_wr = '1' and dn_addr >= x"00000" and dn_addr < x"02000" else '1';
	sprom_a3_we_n <=	'0' when dn_wr = '1' and dn_addr >= x"02000" and dn_addr < x"04000" else '1';
	sprom_a5_we_n <=	'0' when dn_wr = '1' and dn_addr >= x"04000" and dn_addr < x"06000" else '1';
	sprom_a6_we_n <=	'0' when dn_wr = '1' and dn_addr >= x"06000" and dn_addr < x"08000" else '1';
	sprom_data_in <=  dn_data when dn_wr = '1' else x"00";
	sprom_adr_fin <=	dn_addr(12 downto 0) when dn_wr = '1' else sprom_adr;
	
	-- sprite rom/ram a2
	sram_rom_a2 : entity work.sram
		generic map (
			AddrWidth => 13,
			DataWidth => 8
		)
		port map (
			clk  => clk_sys,
			addr => sprom_adr_fin,
			din  => sprom_data_in,
			dout => sprom_a2_data,
			ce_n => '0', 
			we_n => sprom_a2_we_n
		);
		
	-- sprite rom/ram a3
	sram_rom_a3 : entity work.sram
		generic map (
			AddrWidth => 13,
			DataWidth => 8
		)
		port map (
			clk  => clk_sys,
			addr => sprom_adr_fin,
			din  => sprom_data_in,
			dout => sprom_a3_data,
			ce_n => '0', 
			we_n => sprom_a3_we_n
		);
	
	-- sprite rom/ram a5
	sram_rom_a5 : entity work.sram
		generic map (
			AddrWidth => 13,
			DataWidth => 8
		)
		port map (
			clk  => clk_sys,
			addr => sprom_adr_fin,
			din  => sprom_data_in,
			dout => sprom_a5_data,
			ce_n => '0', 
			we_n => sprom_a5_we_n
		);
	
	-- sprite rom/ram a6
	sram_rom_a6 : entity work.sram
		generic map (
			AddrWidth => 13,
			DataWidth => 8
		)
		port map (
			clk  => clk_sys,
			addr => sprom_adr_fin,
			din  => sprom_data_in,
			dout => sprom_a6_data,
			ce_n => '0', 
			we_n => sprom_a6_we_n
		);
	
	-- fill tile rom
	trom_1_we_n  <= '0' when dn_wr = '1' and dn_addr >= x"0e000" and dn_addr < x"10000" and tno(7) = '1' else '1';
	trom_2_we_n  <= '0' when dn_wr = '1' and dn_addr >= x"10000" and dn_addr < x"12000" and tno(7) = '1' else '1';
	trom_3_we_n  <= '0' when dn_wr = '1' and dn_addr >= x"12000" and dn_addr < x"14000" and tno(7) = '1' else '1';
	trom_4_we_n  <= '0' when dn_wr = '1' and dn_addr >= x"14000" and dn_addr < x"16000" and tno(7) = '1' else '1';
	trom_data_in <= dn_data when dn_wr = '1' else x"00";
	trom_adr_fin <= dn_addr(12 downto 0) when dn_wr = '1' else trom_adr;
	
	-- tile rom/ram 1
	tram_rom_1 : entity work.sram
		generic map (
			AddrWidth => 13,
			DataWidth => 8
		)
		port map (
			clk  => clk_sys,
			addr => trom_adr_fin,
			din  => trom_data_in,
			dout => trom_1_data,
			ce_n => '0', 
			we_n => trom_1_we_n
		);
	
	-- tile rom/ram 2
	tram_rom_2 : entity work.sram
		generic map (
			AddrWidth => 13,
			DataWidth => 8
		)
		port map (
			clk  => clk_sys,
			addr => trom_adr_fin,
			din  => trom_data_in,
			dout => trom_2_data,
			ce_n => '0', 
			we_n => trom_2_we_n
		);
	
	-- tile rom/ram 3
	tram_rom_3 : entity work.sram
		generic map (
			AddrWidth => 13,
			DataWidth => 8
		)
		port map (
			clk  => clk_sys,
			addr => trom_adr_fin,
			din  => trom_data_in,
			dout => trom_3_data,
			ce_n => '0', 
			we_n => trom_3_we_n
		);
		
	-- tile rom/ram 4
	tram_rom_4 : entity work.sram
		generic map (
			AddrWidth => 13,
			DataWidth => 8
		)
		port map (
			clk  => clk_sys,
			addr => trom_adr_fin,
			din  => trom_data_in,
			dout => trom_4_data,
			ce_n => '0', 
			we_n => trom_4_we_n
		);
	
	-- palette rom
	palrom : entity work.rom_palette
		port map (
			clk => clk_sys,
			addr => palrom_adr,
			data => palrom_data
		);
    
end;
