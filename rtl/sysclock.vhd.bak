--
-- turbo things added by Niels Lueddecke in 2021
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
-- Erzeugung der Takte fuer KC
--   CPU+CTC
--
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity sysclock is
	port (
		clk			: in std_logic;

		turbo			: in  std_logic_vector(1 downto 0);

		cpuClkEn		: out std_logic; -- 1,7734476 MHz (PALx2: 8,867238 MHz/5)
		h4Clk			: out std_logic; 
		h5ClkEn		: out std_logic; -- 15,694 kHz Clock enable
		biClk			: out std_logic  
	);
end sysclock;

architecture rtl of sysclock is
	constant H4_CLK_MAX		: unsigned(7 downto 0) := x"00" + 32 + 32 + 32 + 16; -- 32 (L) 32 (H) 32 (L) 16 (H) = 112 (15,834 kHz)
	constant BI_CLK_MAX		: unsigned(15 downto 0) := x"0000" + 256 + 56; -- 256 * 112 (L) 56 * 112 (H) = 34.944 (50,75Hz)

	constant c_DIVIDER		: unsigned(7 downto 0) := x"1c";	-- 28
	constant c_FRACT_DIVIER	: unsigned(7 downto 0) := x"05";	-- 5
	
	signal DIVIDER				: unsigned(7 downto 0);
	signal FRACT_DIVIER		: unsigned(7 downto 0);

	signal mainDivider		: unsigned(7 downto 0) := (others => '0');
	signal fractDivider		: unsigned(7 downto 0) := (others => '0');
	signal mainDivider_p		: unsigned(7 downto 0) := (others => '0');
	signal fractDivider_p	: unsigned(7 downto 0) := (others => '0');

	signal mainClkEn			: std_logic;
	signal mainClkEn_p		: std_logic;
	signal h5ClkCounter		: unsigned(7 downto 0);
	signal biClkCounter		: unsigned(15 downto 0);
 
begin
	cpuClkEn <= mainClkEn;
	-- Divider: Reset@ 111 0000 => 112
	-- 32 (L) 32 (H) 32 (L) 16 (H) = 112
	h4Clk <= h5ClkCounter(5);
	-- Divider: Reset@ 1 0011 1000 => 312
	-- 256 (L) 56 (H) 
	biClk <= '0' when biClkCounter < 256 else '1';
    
	-- Ziel: 1,7734476 MHz
	-- genauer Teiler: 28,193681
	-- 50 MHz durch 28,2 dividieren
	--  --> 1,7730496 MHz
	cpuClk : process 
	begin
		wait until rising_edge(clk);

		-- turbo setting
		if		turbo = b"00" then
			DIVIDER      <= c_DIVIDER;
			FRACT_DIVIER <= c_FRACT_DIVIER;
		elsif	turbo = b"01" then
			DIVIDER      <= b"0" & c_DIVIDER(7 downto 1);
			FRACT_DIVIER <= b"0" & c_FRACT_DIVIER(7 downto 1);
		elsif	turbo = b"10" then
			DIVIDER      <= b"00" & c_DIVIDER(7 downto 2);
			FRACT_DIVIER <= b"00" & c_FRACT_DIVIER(7 downto 2);
		elsif	turbo = b"11" then
			DIVIDER      <= b"000" & c_DIVIDER(7 downto 3);
			FRACT_DIVIER <= b"000" & c_FRACT_DIVIER(7 downto 3);
		end if;

		-- for cpu, multiplied by turbo
		if (mainDivider > 0) then
			mainDivider <= mainDivider - 1;
			mainClkEn <= '0';
		else
			if (fractDivider>0) then
				mainDivider <= DIVIDER - 1;
				fractDivider <= fractDivider - 1;
			else
				mainDivider <= DIVIDER;
				fractDivider <= FRACT_DIVIER-1;
			end if;
			mainClkEn <= '1';
		end if;
		
		-- for peripherals, always standard speed
		if (mainDivider_p > 0) then
			mainDivider_p <= mainDivider_p - 1;
			mainClkEn_p <= '0';
		else
			if (fractDivider_p>0) then
				mainDivider_p <= c_DIVIDER - 1;
				fractDivider_p <= fractDivider_p - 1;
			else
				mainDivider_p <= c_DIVIDER;
				fractDivider_p <= c_FRACT_DIVIER-1;
			end if;
			mainClkEn_p <= '1';
		end if;
	end process;
 
    -- Takte fuer CTC (normalerweise aus Videotakt abegeleitet)
    ctcClk : process
    begin
        wait until rising_edge(clk);

        h5ClkEn <= '0';        
        
        if (mainClkEn_p='1') then
            -- H4-Clock
            if (h5ClkCounter<H4_CLK_MAX-1) then
                h5ClkCounter <= h5ClkCounter + 1;
            else 
                h5ClkCounter <= x"00";
                h5ClkEn <= '1';
                
                -- BI-Clock
                if (biClkCounter<BI_CLK_MAX-1) then
                    biClkCounter <= biClkCounter + 1;
                else
                    biClkCounter <= x"0000";
                end if;
            end if;
        end if;
    end process;
    
end;

