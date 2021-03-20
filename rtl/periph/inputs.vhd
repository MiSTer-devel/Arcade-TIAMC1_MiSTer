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
		clk_sys				: in  std_logic;
		reset_n				: in  std_logic;
		
		io_out				: out std_logic_vector(7 downto 0);
		cpuAddr				: in  std_logic_vector(7 downto 0);
		cpuStatus			: in std_logic_vector(7 downto 0);
		cpuDBin				: in  std_logic;
		
		joystick_0			: in  std_logic_vector(31 downto 0);
		joystick_analog_0	: in  std_logic_vector(15 downto 0);
		paddle_0				: in  std_logic_vector(7 downto 0);
		spinner_0			: in  std_logic_vector(8 downto 0);
		cfg_analog			: in  std_logic_vector(2 downto 0);
		VBlank				: in  std_logic;
		tno					: in std_logic_vector(7 downto 0)
	);
end inputs;

architecture rtl of inputs is
	signal axis_x_tmp		: unsigned(7 downto 0) := x"40";
	signal axis_x_tmp_b	: unsigned(7 downto 0) := x"98";
	signal axis_x			: unsigned(7 downto 0);
	signal spinner_last	: std_logic;
	
begin
	process
	begin
		wait until rising_edge(clk_sys);
		
		if reset_n = '0' then
		else
			-- get analog input axis, for Gorodki
			if cfg_analog(1 downto 0) = b"00" then
				-- calc analog x axis, from joystick x
				if cfg_analog(2) = '0' then
					-- invert
					axis_x_tmp <= not (unsigned(joystick_analog_0(7 downto 0)) + x"7f");
				else
					-- no invert
					axis_x_tmp <= unsigned(joystick_analog_0(7 downto 0)) + x"7f";
				end if;
			elsif cfg_analog(1 downto 0) = b"01" then
				-- calc analog x axis, from paddle
				if cfg_analog(2) = '0' then
					-- invert
					axis_x_tmp <= not unsigned(paddle_0);
				else
					-- no invert
					axis_x_tmp <= unsigned(paddle_0);
				end if;
			elsif cfg_analog(1 downto 0) = b"10" then
				-- calc spinner position
				if spinner_last /= spinner_0(8) then
					spinner_last <= spinner_0(8);
					-- calc analog x axis, from spinner
					if cfg_analog(2) = '0' then
						-- invert
						if (unsigned(not spinner_0(7 downto 0)) < x"80" and (axis_x_tmp + unsigned(not spinner_0(6 downto 0) & b"0") + 2 > axis_x_tmp))
							or (unsigned(not spinner_0(7 downto 0)) > x"80" and (axis_x_tmp + unsigned(not spinner_0(6 downto 0) & b"0") + 2 < axis_x_tmp)) then
							axis_x_tmp <= axis_x_tmp + unsigned(not spinner_0(6 downto 0) & b"0") + 2;
						end if;
					else
						-- no invert
						if (unsigned(spinner_0(7 downto 0)) < x"80" and (axis_x_tmp + unsigned(spinner_0(6 downto 0) & b"0") > axis_x_tmp))
							or (unsigned(spinner_0(7 downto 0)) > x"80" and (axis_x_tmp + unsigned(spinner_0(6 downto 0) & b"0") < axis_x_tmp)) then
							axis_x_tmp <= axis_x_tmp + unsigned(spinner_0(6 downto 0) & b"0");
						end if;
					end if;
				end if;
			end if;
			-- keep position within limits
			axis_x_tmp_b <= (b"0" & axis_x_tmp(7 downto 1)) + x"58";
			if axis_x_tmp_b < x"60" then
				axis_x <= x"60";
			elsif axis_x_tmp_b > x"d0" then
				axis_x <= x"d0";
			else
				axis_x <= axis_x_tmp_b;
			end if;
			-- read from inputs io
			if cpuStatus = x"42" and cpuDBin = '1' then
				if tno(7) = '0' then
					-- v1 hardware
					-- in0
					if	cpuAddr(7 downto 0) = x"d0" then
						if tno = x"05" then
							-- analog axis for Gorodki
							io_out    <= std_logic_vector(axis_x);
						else
							-- digital x for all the other games
							io_out    <= x"00";
							io_out(1) <= joystick_0(0);	-- joystick right
							io_out(5) <= joystick_0(1);	-- joystick left
						end if;
					-- in1
					elsif	cpuAddr(7 downto 0) = x"d1" then
						io_out    <= x"00";
						io_out(1) <= joystick_0(3);		-- joystick up
						io_out(5) <= joystick_0(2);		-- joystick down
						io_out(7) <= '0';						-- service
					-- in2
					elsif	cpuAddr(7 downto 0) = x"d2" then
						io_out    <= x"00";
						io_out(1) <= '1';						-- coin lockout
						io_out(3) <= '1';						-- ???
						io_out(4) <= joystick_0(6);		-- coin
						io_out(5) <= joystick_0(4);		-- joystick button 1
						io_out(6) <= joystick_0(5);		-- joystick button 2
						io_out(7) <= VBlank;					-- vblank (waits for 0!)
					end if;
				else
					-- v2 hardware
					-- in0
					if	cpuAddr(7 downto 0) = x"d0" then
						io_out    <= x"11";
						io_out(1) <= not joystick_0(0);	-- joystick right
						io_out(5) <= not joystick_0(1);	-- joystick left
					-- in1
					elsif	cpuAddr(7 downto 0) = x"d1" then
						io_out    <= x"11";
						io_out(1) <= not joystick_0(3);	-- joystick up
						io_out(5) <= not joystick_0(2);	-- joystick down
						io_out(7) <= '1';						-- service
					-- in2
					elsif	cpuAddr(7 downto 0) = x"d2" then
						io_out    <= x"00";	
						io_out(1) <= '1';						-- coin lockout
						io_out(3) <= '1';						-- ???
						io_out(4) <= joystick_0(6);		-- coin
						io_out(5) <= not joystick_0(4);	-- joystick button 1
						io_out(6) <= not joystick_0(5);	-- joystick button 2
						io_out(7) <= VBlank;					-- vblank (waits for 0!)
					end if;
				end if;
			end if;
		end if;
	end process;
end;
