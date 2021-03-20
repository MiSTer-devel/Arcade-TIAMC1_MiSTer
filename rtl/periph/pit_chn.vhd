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

entity pit_channel is 
	port (
		clk				: in  std_logic;
		tick_cpu			: in  std_logic;
		tick_clk			: in  std_logic;
		reset_n			: in  std_logic;
		
		load_cnt			: in  std_logic;
		set_mode			: in  std_logic;
		mode_in			: in  std_logic_vector(5 downto 0);
		cnt_in			: in  std_logic_vector(7 downto 0);
		
		gate_in			: in  std_logic;
		counter_out		: out std_logic
	);
end pit_channel;

architecture rtl of pit_channel is
	type   state_type is ( stopped, running, load_start, load_complete );
	type   load_type is ( load_high, load_low, load_both );
	type   load_state_type is ( load_both_high, load_both_low );
	signal state  			: state_type := stopped;
	signal load_mode		: load_type := load_both;
	signal load_state		: load_state_type := load_both_low;
	signal count			: unsigned(15 downto 0) := (others => '0');
	signal count_default	: unsigned(15 downto 0) := (others => '0');
	signal mode				: std_logic_vector(2 downto 0);
	signal gate_in_old	: std_logic;
	signal load_cnt_old	: std_logic;
	signal set_mode_old	: std_logic;
	
begin
	process
	begin
		wait until rising_edge(clk);
		
		-- modes 0, 3, 4 will be needed, afaik
		
		-- reset
		if reset_n = '0' then
			count 		  <= x"0000";
			count_default <= x"0000";
			mode  		  <= b"000";
			state 		  <= stopped;
			counter_out   <= '1';
		else
			-- operate at input clock tick rate
			if tick_clk = '1' then	
				-- handle modes, only 0, 3, 4 for now...
				gate_in_old <= gate_in;
				-- mode 0
				if		mode = b"000" then
					-- counter loaded
					if		state = load_complete then
						state <= running;
						count	<= count - 1;
					elsif	gate_in = '1' and state = running then
						count <= count - 1;
						if count = 0 then
							counter_out	<= '1';
						end if;
					end if;
				-- mode 3
				elsif	mode(1 downto 0) = b"11" then
					-- counter loaded
					if		state = load_complete then
						state <= running;
						count	<= count - 1;
					elsif	gate_in = '1' and state = running then
						count <= count - 1;
						if count = 0 then
							count	<= count_default;
						end if;
						if count_default > 20 and count > b"0" & count_default(15 downto 1) then
							counter_out	<= '1';
						else
							counter_out	<= '0';
						end if;
					elsif	gate_in = '0' and state = running then
						counter_out	<= '1';
					elsif	gate_in = '1' and gate_in_old = '0' then
						count	<= count_default;
						state <= running;
					end if;
				-- mode 4
				elsif	mode = b"100" then
					-- counter loaded
					if		state = load_complete then
						state <= running;
						count	<= count - 1;
					elsif	gate_in = '1' and state = running then
						count <= count - 1;
						if count /= 0 then
							counter_out	<= '1';
						else
							counter_out	<= '0';
						end if;
					end if;
				end if;
			end if;
				
			-- operate at cpu clock rate
			-- update mode on rising edge
			set_mode_old <= set_mode;
			if set_mode = '1' and set_mode_old = '0' then
				mode <= mode_in(3 downto 1);
				-- start loading counter bytes
				if 	mode_in(5 downto 4) = b"10" then
					-- load upper byte
					state      <= load_start;
					load_mode  <= load_high;
				elsif mode_in(5 downto 4) = b"01" then
					-- load lower byte
					state      <= load_start;
					load_mode  <= load_low;
				elsif mode_in(5 downto 4) = b"11" then
					-- load lower byte first, then upper
					state      <= load_start;
					load_mode  <= load_both;
					load_state <= load_both_low;
				else
					-- latch comand for read, ignore
					--state <= stopped;
				end if;
				-- initial output state after loading mode byte
				if		mode_in(3 downto 1) = b"000" then
					-- mode 0
					counter_out	<= '0';
				elsif	mode_in(2 downto 1) = b"11" then
					-- mode 3
					counter_out	<= '1';
				elsif	mode_in(3 downto 1) = b"100" then
					-- mode 4
					counter_out	<= '1';
				end if;
			end if;
			
			-- load counter on rising edge
			load_cnt_old <= load_cnt;
			if load_cnt = '1' and load_cnt_old = '0' then
				case load_mode is
					when load_high =>
						count				<= unsigned(cnt_in & x"00");
						count_default	<= unsigned(cnt_in & x"00");
						state				<= load_complete;
					when load_low =>
						count				<= unsigned(x"00" & cnt_in);
						count_default	<= unsigned(x"00" & cnt_in);
						state				<= load_complete;
					when load_both =>
						if load_state = load_both_low then
							count(7 downto 0)				<= unsigned(cnt_in);
							count_default(7 downto 0)	<= unsigned(cnt_in);
							load_state						<= load_both_high;
						else
							count(15 downto 8)			<= unsigned(cnt_in);
							count_default(15 downto 8)	<= unsigned(cnt_in);
							load_state 						<= load_both_low;
							state								<= load_complete;
						end if;
					when others =>
					end case;
			end if;
		end if;
	end process;
end;
