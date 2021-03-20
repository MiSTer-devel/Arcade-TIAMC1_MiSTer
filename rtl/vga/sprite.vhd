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

entity sprite is 
	port (
		clk				: in  std_logic;
		reset_n			: in  std_logic;
		en_n				: in  std_logic;
		in_update		: in  std_logic_vector(7 downto 0);
		in_draw_pixel	: in  std_logic;
		
		in_screen_x		: in  unsigned(7 downto 0);
		in_screen_y		: in  unsigned(7 downto 0);
		
		in_pos_x			: in  unsigned(7 downto 0);
		in_pos_y			: in  unsigned(7 downto 0);
		in_attrib		: in  std_logic_vector(7 downto 0);
		
		out_color		: out std_logic_vector(3 downto 0);
		
		in_data_a		: in  std_logic_vector(7 downto 0);
		in_data_b		: in  std_logic_vector(7 downto 0);
		in_data_c		: in  std_logic_vector(7 downto 0);
		in_data_d		: in  std_logic_vector(7 downto 0);
		in_data_adr		: in  std_logic_vector(7 downto 0)
	);
end sprite;

architecture rtl of sprite is
	type SpDataType is array(31 downto 0) of std_logic_vector(7 downto 0);
	
	signal sp_data_a		: SpDataType := (others => (others => '0'));
	signal sp_data_b		: SpDataType := (others => (others => '0'));
	signal sp_data_c		: SpDataType := (others => (others => '0'));
	signal sp_data_d		: SpDataType := (others => (others => '0'));

	signal pos_x			: unsigned(7 downto 0);
	signal pos_y			: unsigned(7 downto 0);
	signal pos_ix			: unsigned(7 downto 0);
	signal pos_iy			: unsigned(7 downto 0);
	signal attrib			: std_logic_vector(7 downto 0);
	signal show_pixel		: std_logic := '0';
	
begin
	process
	begin
		wait until rising_edge(clk);
		
		-- reset
		if reset_n = '0' then
		-- update things
		elsif en_n ='0' then
			-- sprite position y
			if		in_update= x"01" then
				pos_y <= in_pos_y;
			-- sprite position x
			elsif	in_update= x"02" then
				pos_x <= in_pos_x;
			-- sprite attributes
			elsif	in_update= x"08" then
				attrib <= in_attrib;
			-- sprite data
			elsif in_update= x"20" then
				sp_data_a(to_integer(unsigned(in_data_adr))) <= in_data_a;
				sp_data_b(to_integer(unsigned(in_data_adr))) <= in_data_b;
				sp_data_c(to_integer(unsigned(in_data_adr))) <= in_data_c;
				sp_data_d(to_integer(unsigned(in_data_adr))) <= in_data_d;
			end if;
		end if;
		
		-- start pixel color output
		if in_draw_pixel = '1' then
			-- sprite hit?
			if attrib(0) = '0' and (pos_x+15-in_screen_x) < 16 and (pos_y+15-in_screen_y) < 16 then
				-- calc in sprite positions
				pos_ix <= in_screen_x(7 downto 0) - pos_x;
				pos_iy <= in_screen_y(7 downto 0) - pos_y;
				show_pixel <= '1';
			else
				out_color  <= x"f";
			end if;
		end if;
		
		-- output pixel color
		if show_pixel = '1' then
			show_pixel <= '0';
			--out_color <= std_logic_vector(pos_ix(3 downto 0));
			-- flip x
			if attrib(3) = '1' then
				-- flip y
				if attrib(1) = '1' then
					-- straight sprite
					out_color <=  sp_data_d(to_integer(pos_iy(3 downto 0) & pos_ix(3)))(to_integer(not pos_ix(2 downto 0)))
									& sp_data_c(to_integer(pos_iy(3 downto 0) & pos_ix(3)))(to_integer(not pos_ix(2 downto 0)))
									& sp_data_b(to_integer(pos_iy(3 downto 0) & pos_ix(3)))(to_integer(not pos_ix(2 downto 0)))
									& sp_data_a(to_integer(pos_iy(3 downto 0) & pos_ix(3)))(to_integer(not pos_ix(2 downto 0)));
				else
					-- sprite flip y
					out_color <=  sp_data_d(to_integer(not pos_iy(3 downto 0) & pos_ix(3)))(to_integer(not pos_ix(2 downto 0)))
									& sp_data_c(to_integer(not pos_iy(3 downto 0) & pos_ix(3)))(to_integer(not pos_ix(2 downto 0)))
									& sp_data_b(to_integer(not pos_iy(3 downto 0) & pos_ix(3)))(to_integer(not pos_ix(2 downto 0)))
									& sp_data_a(to_integer(not pos_iy(3 downto 0) & pos_ix(3)))(to_integer(not pos_ix(2 downto 0)));
				end if;
			else
				-- flip y
				if attrib(1) = '1' then
					-- sprite flip x
					out_color <=  sp_data_d(to_integer(pos_iy(3 downto 0) & not pos_ix(3)))(to_integer(pos_ix(2 downto 0)))
									& sp_data_c(to_integer(pos_iy(3 downto 0) & not pos_ix(3)))(to_integer(pos_ix(2 downto 0)))
									& sp_data_b(to_integer(pos_iy(3 downto 0) & not pos_ix(3)))(to_integer(pos_ix(2 downto 0)))
									& sp_data_a(to_integer(pos_iy(3 downto 0) & not pos_ix(3)))(to_integer(pos_ix(2 downto 0)));
				else
					-- sprite flip y
					out_color <=  sp_data_d(to_integer(not pos_iy(3 downto 0) & not pos_ix(3)))(to_integer(not pos_ix(2 downto 0)))		-- x and y
									& sp_data_c(to_integer(not pos_iy(3 downto 0) & not pos_ix(3)))(to_integer(not pos_ix(2 downto 0)))
									& sp_data_b(to_integer(not pos_iy(3 downto 0) & not pos_ix(3)))(to_integer(not pos_ix(2 downto 0)))
									& sp_data_a(to_integer(not pos_iy(3 downto 0) & not pos_ix(3)))(to_integer(not pos_ix(2 downto 0)));
				end if;
			end if;
		end if;
	end process;
end;
