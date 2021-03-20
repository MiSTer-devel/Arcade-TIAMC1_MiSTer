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

entity sysclock is
	port (
		clk_sys			: in std_logic;	-- 31,5 MHz
		reset_n			: in  std_logic;
		tick_cpu			: out std_logic;	-- 1,75 MHz (clk_sys / 18)
		tick_vid			: out std_logic	-- 5,25 MHz (clk_sys / 6)
	);
end sysclock;

architecture rtl of sysclock is
	signal cnt_cpu		: unsigned(7 downto 0) := (others => '0');
	signal cnt_vid		: unsigned(3 downto 0) := (others => '0');
 
begin

	cpuClk : process 
	begin
		wait until rising_edge(clk_sys);
		
		-- reset
		if reset_n = '0' then
			cnt_cpu	<= x"11";
			tick_cpu	<= '0';
			cnt_vid	<= x"5";
			tick_vid	<= '0';
		else
			-- tick cpu
			if (cnt_cpu > 0) then
				cnt_cpu	<= cnt_cpu - 1;
				tick_cpu	<= '0';
			else
				cnt_cpu	<= x"11";
				tick_cpu	<= '1';
			end if;
			
			-- tick vid
			if (cnt_vid > 0) then
				cnt_vid	<= cnt_vid - 1;
				tick_vid	<= '0';
			else
				cnt_vid	<= x"5";
				tick_vid	<= '1';
			end if;
		end if;
	end process;
    
end;

