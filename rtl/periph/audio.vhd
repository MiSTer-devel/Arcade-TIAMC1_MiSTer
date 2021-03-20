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

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all; 

entity audio is 
	port (
		clk_sys			: in  std_logic;
		tick_cpu			: in  std_logic;
		clk_audio		: in  std_logic;		-- 24.576 MHz
		reset_n			: in  std_logic;
		
		AUDIO_L			: out std_logic_vector(15 downto 0);
		AUDIO_R			: out std_logic_vector(15 downto 0);
		
		cpuWR_n			: in  std_logic;
		cpuStatus		: in  std_logic_vector(7 downto 0);
		cpuAddr			: in  std_logic_vector(15 downto 0);
		cpuDIn			: in  std_logic_vector(7 downto 0);
		tno				: in std_logic_vector(7 downto 0);
		
		TMP_DBG			: out std_logic_vector(7 downto 0)
	);
end audio;

architecture rtl of audio is
	-- audio signals
	signal audio_out_a	: std_logic;
	signal audio_out_b	: std_logic;
	signal audio_out		: std_logic;
	
	-- channel components
	signal tick_clk		: std_logic_vector(5 downto 0);
	signal load_cnt		: std_logic_vector(5 downto 0);
	signal set_mode		: std_logic_vector(5 downto 0);
	signal tmp_mode		: std_logic_vector(5 downto 0);
	signal tmp_count		: std_logic_vector(7 downto 0);
	signal counter_gate	: std_logic_vector(5 downto 0);
	signal counter_out	: std_logic_vector(5 downto 0);
	
	-- clock divide
	signal div_clk			: unsigned(11 downto 0) := (others => '0');
	
begin
	-- control process
	ctrl_in : process
	begin
		wait until rising_edge(clk_sys);
		
		-- defaults
		load_cnt <= (others => '0');
		set_mode <= (others => '0');

		-- io writes
		if cpuStatus = x"10" and cpuWR_n = '0' and tick_cpu = '1' then
			-- fill temp registers
			tmp_mode  <= cpuDIn(5 downto 0);
			-- 1st 8253, load counter 0
			if		cpuAddr(7 downto 0) = x"c0" then
				load_cnt  <= b"000001";
				tmp_count <= cpuDIn;
			-- 1st 8253, load counter 1
			elsif	cpuAddr(7 downto 0) = x"c1" then
				load_cnt <= b"000010";
				tmp_count <= cpuDIn;
			-- 1st 8253, load counter 2
			elsif	cpuAddr(7 downto 0) = x"c2" then
				load_cnt <= b"000100";
				tmp_count <= cpuDIn;
			-- 1st 8253, mode word
			elsif	cpuAddr(7 downto 0) = x"c3" then
				if		cpuDIn(7 downto 6) = b"00" then
					-- channel 0
					set_mode <= b"000001";
				elsif	cpuDIn(7 downto 6) = b"01" then
					-- channel 1
					set_mode <= b"000010";
				elsif	cpuDIn(7 downto 6) = b"10" then
					-- channel 2
					set_mode <= b"000100";
				end if;
			-- 2nd 8253, load counter 0
			elsif	cpuAddr(7 downto 0) = x"d4" then
				load_cnt <= b"001000";
				tmp_count <= cpuDIn;
			-- 2nd 8253, load counter 1
			elsif	cpuAddr(7 downto 0) = x"d5" then
				load_cnt <= b"010000";
				tmp_count <= cpuDIn;
			-- 2nd 8253, load counter 2
			elsif	cpuAddr(7 downto 0) = x"d6" then
				load_cnt <= b"100000";
				tmp_count <= cpuDIn;
			-- 2nd 8253, mode word
			elsif	cpuAddr(7 downto 0) = x"d7" then
				if		cpuDIn(7 downto 6) = b"00" then
					-- channel 0
					set_mode <= b"001000";
				elsif	cpuDIn(7 downto 6) = b"01" then
					-- channel 1
					set_mode <= b"010000";
				elsif	cpuDIn(7 downto 6) = b"10" then
					-- channel 2
					set_mode <= b"100000";
				end if;
			-- 2nd 8253, gate control (will be written to b00000111 afaik)
			elsif	cpuAddr(7 downto 0) = x"da" then
				counter_gate(5 downto 3) <= cpuDIn(2 downto 0);
			end if;
		end if;
		
		-- v1 hardware
		if tno(7) = '0' then
			-- finalize audio output
			audio_out_a <= (counter_out(0) xor counter_out(1)) and counter_out(2);
			-- handle gates
			-- timer 0 gates come from timer 1 outputs
			counter_gate(0) <= counter_out(3);
			counter_gate(1) <= counter_out(4);
			counter_gate(2) <= counter_out(5);
		else
			-- v2 hardware
			-- finalize audio output
			audio_out_a <= counter_out(2);
			-- timer 0 gates
			counter_gate(0) <= '1';
			counter_gate(1) <= '1';
			counter_gate(2) <= '1';
		end if;
		
		-- pass clock ticks to timers
		-- timer 0 to 2 work on cpu frequency
		tick_clk(0) <= tick_cpu;
		tick_clk(1) <= tick_cpu;
		tick_clk(2) <= tick_cpu;
		-- timer 3 to 5 work on 7812 Hz ticks (31,5 MHz / 4032)
		if div_clk > 0 then
			div_clk		<= div_clk - 1;
			tick_clk(3) <= '0';
			tick_clk(4) <= '0';
			tick_clk(5) <= '0';
		else
			div_clk		<= x"fc0";
			tick_clk(3) <= '1';
			tick_clk(4) <= '1';
			tick_clk(5) <= '1';
		end if;
		
		-- DEBUG out
		TMP_DBG(2 downto 0) <= counter_out(2 downto 0);
		TMP_DBG(4 downto 3) <= counter_gate(1 downto 0);
		TMP_DBG(5) <= audio_out_a;
		TMP_DBG(6) <= audio_out_a;
		TMP_DBG(7) <= '1';
	end process;
	
	-- audio output process
	audio_out_proc : process
	begin
		wait until rising_edge(clk_audio);
		
		-- clock crossing
		audio_out_b <= audio_out_a;
		audio_out   <= audio_out_b;
	
		-- play audio
		if audio_out = '1' then
			AUDIO_L <= x"ff00";
			AUDIO_R <= x"ff00";
		else
			AUDIO_L <= x"0000";
			AUDIO_R <= x"0000";
		end if;
	end process;
	
	-- 8253 channel components
	pit_channels: for i in 0 to 5 generate
        pit_channel : entity work.pit_channel
        port map (
            clk			=> clk_sys,
				tick_cpu		=> tick_cpu,
				tick_clk		=> tick_clk(i),
            reset_n 		=> reset_n,
				
				load_cnt		=> load_cnt(i),
				set_mode		=> set_mode(i),
				mode_in		=> tmp_mode,
				cnt_in		=> tmp_count,
				
				gate_in		=> counter_gate(i),
				counter_out => counter_out(i)
        );
	end generate;
end;
