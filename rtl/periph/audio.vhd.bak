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
		clk				: in  std_logic;		-- 24.576 MHz
		reset_n			: in  std_logic;
		
		AUDIO_L			: out std_logic_vector(15 downto 0);
		AUDIO_R			: out std_logic_vector(15 downto 0);
		
		audioEn_n		: in  std_logic;
		tapeEn			: in  std_logic;
		
		tape_out			: in  std_logic;
		
		pioB				: in  std_logic_vector(7 downto 0);
		
		ctcTcTo			: in  std_logic_vector(1 downto 0)
	);
end audio;

	architecture rtl of audio is
		signal divide_frq		: unsigned(16 downto 0) := (others => '0');
		
		signal ctc_to_a		: std_logic_vector(1 downto 0);
		signal ctc_to_b		: std_logic_vector(1 downto 0);
		signal ctc_to			: std_logic_vector(1 downto 0);
		signal tape_out_a		: std_logic := '0';
		signal tape_out_b		: std_logic := '0';
		signal tape_out_sig	: std_logic := '0';
		
		signal level			: std_logic_vector(1 downto 0) := (others => '0');
		signal tape_out_old	: std_logic := '0';
		signal ctcTcTo_old	: std_logic_vector(1 downto 0) := (others => '0');
		
		signal sig_noise		: std_logic_vector(1 downto 0) := (others => '0');
	
begin
	process
	begin
		wait until rising_edge(clk);
		
		-- cross clocks
		ctc_to_a    <= ctcTcTo;
		ctc_to_b    <= ctc_to_a;
		ctc_to      <= ctc_to_b;
		tape_out_a   <= tape_out;
		tape_out_b   <= tape_out_a;
		tape_out_sig <= tape_out_b;
		
		-- detect audio
		-- tape
		if tape_out_old /= tape_out_sig and tape_out_sig = '1' and tapeEn = '1' then
			sig_noise(1) <= '1';
		end if;
		tape_out_old <= tape_out_sig;
		-- audio out 0
		if ctcTcTo_old(0) /= ctc_to(0) and ctc_to(0) = '1' and audioEn_n = '0' then
			sig_noise(0) <= '1';
		end if;
		ctcTcTo_old(0) <= ctc_to(0);
		-- audio out 1
		if ctcTcTo_old(1) /= ctc_to(1) and ctc_to(1) = '1' and audioEn_n = '0' then
			sig_noise(1) <= '1';
		end if;
		ctcTcTo_old(1) <= ctc_to(1);
		
--		-- play audio
		divide_frq <= divide_frq + 1;
		if divide_frq(4 downto 0) = b"00000" then
			if sig_noise(0) = '1' then
				sig_noise(0) <= '0';
				level(0) <= not level(0);
				AUDIO_L <= level(0) & level(0) & level(0) & b"0000000000000";
			end if;
			if sig_noise(1) = '1' then
				sig_noise(1) <= '0';
				level(1) <= not level(1);
				AUDIO_R <= level(1) & level(1) & level(1) & b"0000000000000";
			end if;
		end if;
	end process;
end;
