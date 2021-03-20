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

entity inputs is 
	port (
		clk_sys			: in  std_logic;
		reset_n			: in  std_logic;
		
		io_out			: out std_logic_vector(7 downto 0);
		cpuAddr			: in  std_logic_vector(7 downto 0);
		cpuStatus		: in std_logic_vector(7 downto 0);
		cpuDBin			: in  std_logic;
		
		joystick_0		: in  std_logic_vector(31 downto 0);
		VBlank			: in  std_logic
	);
end inputs;

	architecture rtl of inputs is
	
begin
	process
	begin
		wait until rising_edge(clk_sys);
		
		if reset_n = '0' then
		else
			-- read from inputs io
			if cpuStatus = x"42" and cpuDBin = '1' then
				-- in0
				if	cpuAddr(7 downto 0) = x"d0" then
					io_out    <= x"00";
					io_out(1) <= joystick_0(0);	-- joystick right
					io_out(5) <= joystick_0(1);	-- joystick left
				end if;
				-- in1
				if	cpuAddr(7 downto 0) = x"d1" then
					io_out    <= x"00";
					io_out(1) <= joystick_0(3);	-- joystick up
					io_out(5) <= joystick_0(2);	-- joystick down
				end if;
				-- in2
				if	cpuAddr(7 downto 0) = x"d2" then
					io_out    <= x"00";
					io_out(1) <= '1';					-- coin lockout
					io_out(3) <= '1';					-- ???
					io_out(4) <= joystick_0(6);	-- coin
					io_out(5) <= joystick_0(4);	-- joystick button 1
					io_out(6) <= joystick_0(5);	-- joystick button 2
					io_out(7) <= VBlank;				-- vblank
				end if;
			end if;
		end if;
	end process;
end;
