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
-- Bruecke zwischen Video-Timing und Pixelgenerator und dem Rest des Systems
--
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity video is
    generic (
        DITHER_MODE : integer := 0
    );
    port (
			cpuclk			: in  std_logic;
			vidclk			: in  std_logic;

			vidH5ClkEn		: in  std_logic;

			vgaRed			: out std_logic_vector(7 downto 0);
			vgaGreen			: out std_logic_vector(7 downto 0);
			vgaBlue			: out std_logic_vector(7 downto 0);
			vgaHSync			: out std_logic;
			vgaVSync			: out std_logic;
			vgaHBlank		: out std_logic;
			vgaVBlank		: out std_logic;

			vidAddr			: out std_logic_vector(13 downto 0);
			vidData			: in  std_logic_vector(15 downto 0);
			vidRead			: in  std_logic;
			vidBusy			: in  std_logic;

			vidHires			: in  std_logic;

			vidBlink			: in  std_logic;
			vidBlinkEn		: in  std_logic;

			vidBlank			: in  std_logic;

			vidScanline		: in  std_logic;
			
			bi_n				: out std_logic;
			h4					: out std_logic
			);
end video;

architecture rtl of video is
    constant KC_VIDLINES : integer := 312;

    type   ram_type is ( ramAddr, ramAddrDelay, ramRead );
    signal ramState			: ram_type := ramAddr;

    signal lineAddr			: integer range 0 to 41 := 41;
    signal row					: std_logic_vector(7 downto 0) := (others => '0');
    signal lineAddrSLV		: std_logic_vector(5 downto 0);
    
    signal vgaAddr			: std_logic_vector(5 downto 0);
    signal vgaData			: std_logic_vector(15 downto 0);
	 signal vidNextLine		: std_logic;
	 signal vidNextLine_a	: std_logic;
	 signal vidNextLine_b	: std_logic;
    
    signal vidBlinkDelay	: std_logic_vector(1 downto 0) := "00";
    signal blinkDiv			: std_logic := '0';
    signal blinkDivEn		: std_logic;
    
    signal vidLine			: std_logic_vector(8 downto 0);
	 signal vidLine_a			: std_logic_vector(8 downto 0);
	 signal vidLine_b			: std_logic_vector(8 downto 0);
	 
	 signal bi_n_a				: std_logic;
	 signal bi_n_b				: std_logic;
	 signal h4_a				: std_logic;
	 signal h4_b				: std_logic;
    
    signal vDisplay			: std_logic;
    
    signal kcVidLine			: integer range 0 to KC_VIDLINES-1 := 0;
    signal kcVidLineSLV		: std_logic_vector(8 downto 0);
    signal vgaBlink			: std_logic;

begin

    -- Adresse im SRAM
    vidAddr <= std_logic_vector(to_unsigned(lineAddr,6)) & row;

	-- Steuerung fuer Zugriff auf SRAM und Scanline-Buffer
	mem : process
	begin
		wait until rising_edge(cpuclk);

		-- Signale aus der anderen Clockdomain einsynchronisieren...
		vidNextLine_b <= vidNextLine_a;
		vidNextLine   <= vidNextLine_b;
		vidLine_b <= vidLine_a;
		vidLine   <= vidLine_b;
		bi_n_b <= bi_n_a;
		bi_n   <= bi_n_b;
		h4_b   <= h4_a;
		h4     <= h4_b;

		if (vidNextLine = '1') then -- naechste Zeile starten?
			row      <= vidLine(7 downto 0);
			lineAddr <= 0; -- reset linebuffer + kopieren starten
			ramState <= ramAddr;
		elsif (lineAddr < 40) then  -- weitere Bytes kopieren?
			case ramState is
				when ramAddr =>
					ramState <= ramAddrDelay;
					lineAddr <= lineAddr + 1;
				when ramAddrDelay =>
					ramState <= ramRead;
				when ramRead =>
					if (vidRead='1') then
						ramState <= ramAddr;
					end if;
			end case;
		else
			lineAddr <= 41;  -- get lineaddress into defined not used state
		end if;
	end process;
 
    lineAddrSLV <= std_logic_vector(to_unsigned(lineAddr,6));
    
    -- Buffer fuer einzelne Scanline
    --  ueberbrueckt die beiden Clockdomains
    linebuffer : entity work.dualsram
    generic map (
        ADDRWIDTH => 6,
        DATAWIDTH => 16
    )
    port map (
        clk1   => cpuclk,
        clk2   => vidclk,
        addr1  => lineAddrSLV,
        addr2  => vgaAddr,
        din1   => vidData,
        din2   => "0000000000000000",
        dout1  => open,
        dout2  => vgaData,
        wr1_n  => '0',
        wr2_n  => '1',
        cs1_n  => '0',
        cs2_n  => '0'
    );
    
    vidBlinkDelay(0) <= vidBlink;

    -- Flankenerkennung und Flip-/Flop fuer Halbierung des Blinktaktes
    blink : process
    begin
        wait until rising_edge(cpuclk);
        vidBlinkDelay(1) <= vidBlinkDelay(0);
        
        if (vidBlinkEn='1') then
            if (vidBlinkDelay="01") then
                blinkDiv <= not blinkDiv;
            end if;
        else
            blinkDiv <= '1';
        end if;
    end process;
    
    -- Zeilenzaehler fuer KC-Seite
    kcLineCounter : process
    begin
        wait until rising_edge(cpuclk);
        
        if (vidH5ClkEn = '1') then
            if (kcVidLine<KC_VIDLINES-1) then
                kcVidLine <= kcVidLine + 1;
            else
                kcVidLine <= 0;
            end if;
        end if;
    end process;
    
	 vidLine_a(8) <= '0'; -- Zeilen auf VGA-Seite gehen nur von 0..255
    kcVidLineSLV <= std_logic_vector(to_unsigned(kcVidLine,kcVidLineSLV'length));
    
    -- Puffer fuer Blinksignal pro Videozeile
    blinkbuffer : entity work.dualsram
    generic map (
        ADDRWIDTH => 9,
        DATAWIDTH => 1
    )
    port map (
        clk1   => cpuclk,
        clk2   => vidclk,
        addr1  => kcVidLineSLV,
        addr2  => vidLine_a,
        din1(0) => blinkDiv,
        din2   => "0",
        dout1  => open,
        dout2(0)  => vgaBlink,
        wr1_n  => not vidH5ClkEn,
        wr2_n  => '1',
        cs1_n  => '0',
        cs2_n  => '0'
    );
    
    -- Timing- und Pixelgenerator instanziieren
    vidgen : entity work.vidgen
    port map (
        vidclk    => vidclk,
        
        vgaRed    => vgaRed,
        vgaGreen  => vgaGreen,
        vgaBlue   => vgaBlue,
        vgaHSync  => vgaHSync,
        vgaVSync  => vgaVSync,
		  vgaHBlank => vgaHBlank,
        vgaVBlank => vgaVBlank,
        
        vgaAddr   => vgaAddr,
        vgaData   => vgaData,
        
        vidHires  => vidHires,
        
        vidBlink  => vgaBlink,
        
        vidBlank  => vidBlank,
        
        vidScanline => vidScanline,
        
		  vidNextLine => vidNextLine_a,
        
		  vidLine   => vidLine_a(7 downto 0),
		  
		  bi_n      => bi_n_a,
		  h4			=> h4_a
    );
    
end;
