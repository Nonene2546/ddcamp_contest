-------------------------------------------------------------------------------------------------------
-- Copyright (c) 2017, Design Gateway Co., Ltd.
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without modification,
-- are permitted provided that the following conditions are met:
-- 1. Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- 2. Redistributions in binary form must reproduce the above copyright notice,
-- this list of conditions and the following disclaimer in the documentation
-- and/or other materials provided with the distribution.
--
-- 3. Neither the name of the copyright holder nor the names of its contributors
-- may be used to endorse or promote products derived from this software
-- without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
-- IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
-- INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
-- PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
-- OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
-- EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
-------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
-- Filename     TestPatt.vhd
-- Title        Top
--
-- Company      Design Gateway Co., Ltd.
-- Project      DDCamp HDMI-IP
-- PJ No.       
-- Syntax       VHDL
-- Note         

-- Version      2.00
-- Author       J.Natthapat
-- Date         2018/12/1
-- Remark       Add DipSwitch to select pattern (Vertical Color Bar, Horizontal Color Bar, Red Screen, and Blue Screen)

-- Version      1.00
-- Author       B.Attapon
-- Date         2017/11/17
-- Remark       New Creation
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

Entity BitmapPattern Is
	Port
	(
		RstB			: in	std_logic;
		Clk				: in	std_logic;

		-- RX input
		RxWrData		: in	std_logic_vector(7 downto 0);
		RxWrEn			: in	std_logic;
		
		-- HDMI Data Interface
		HDMIFfWrEn		: out	std_logic;
		HDMIFfWrData	: out	std_logic_vector( 23 downto 0 );
		HDMIFfWrCnt		: in	std_logic_vector( 7 downto 0 )
	);
End Entity BitmapPattern;

Architecture rtl Of BitmapPattern Is

----------------------------------------------------------------------------------
-- Constant Declaration
----------------------------------------------------------------------------------
	
----------------------------------------------------------------------------------
-- Signal declaration
----------------------------------------------------------------------------------
	
	type SerStateType Is 
						(
							stHeader,
							stData
						);
						
	signal	rState			: SerStateType;
	
	signal	rHDMIFfWrEn		: std_logic;
	signal	rBitMap			: std_logic_vector(23 downto 0);

	signal	rHdCnt			: std_logic_vector(5 downto 0);
	signal	rRGBCnt			: std_logic_vector(1 downto 0);
	signal	rPxCnt			: std_logic_vector(19 downto 0);
	
Begin

----------------------------------------------------------------------------------
-- Output assignment
----------------------------------------------------------------------------------
	
	HDMIFfWrEn					<= rHDMIFfWrEn;
	HDMIFfWrData(23 downto 0)	<= rBitMap(23 downto 0);
	
----------------------------------------------------------------------------------
-- DFF 
----------------------------------------------------------------------------------
	
	u_rHdCnt : Process(Clk) IS
	Begin
		if(rising_edge(Clk)) then
			if(RstB = '0') then
				rHdCnt <= (others => '0');
			else
				if(rState = stHeader) then
					if(RxWrEn = '1') then
						rHdCnt <= rHdCnt + 1;
					else
						rHdCnt <= rHdCnt;
					end if;
				else
					rHdCnt <= (others => '0');
				end if;
			end if;
		end if;
	end process u_rHdCnt;
	
	u_rRGBCnt : Process(Clk) IS
	Begin
		if(rising_edge(Clk)) then
			if(RstB = '0') then
				rRGBCnt <= "00";
			else
				if(rRGBCnt = "11" or rState = stHeader) then
					rRGBCnt <= "00";
				elsif(RxWrEn = '1') then
					rRGBCnt <= rRGBCnt + 1;
				else
					rRGBCnt <= rRGBCnt;
				end if;
			end if;
		end if;
	end Process u_rRGBCnt;
	
	u_rPxCnt : Process(Clk) IS
	Begin
		if(rising_edge(Clk)) then
			if(RstB = '0') then
				rPxCnt <= (others => '0');
			else
				if(rPxCnt = 786432) then
					rPxCnt <= (others => '0');
				elsif(rHDMIFfWrEn = '1') then
					rPxCnt <= rPxCnt + 1;
				else
					rPxCnt <= rPxCnt;
				end if;	
			end if;
		end if;
	end Process u_rPxCnt;
	
	u_rBitMap : Process(Clk) Is
	Begin
		if(rising_edge(Clk)) then
			if(RstB = '0') then
				rBitMap <= (others => '0');
			elsif(RxWrEn = '1') then
				rBitMap(23 downto 0) <= RxWrData(7 downto 0) & rBitMap(23 downto 8);
			else
				rBitMap <= rBitMap;
			end if;	
		end if;
	end Process u_rBitMap;
	
	u_rHDMIFfWrEn : Process (Clk) Is
	Begin
		if ( rising_edge(Clk) ) then
			if ( RstB='0' ) then
				rHDMIFfWrEn <= '0';
			else
				if(rRGBCnt = "11") then
					rHDMIFfWrEn <= '1';
				else
					rHDMIFfWrEn <= '0';
				end if;
			end if;
		end if;
	End Process u_rHDMIFfWrEn;
	
	u_rState : Process(Clk) IS
	Begin
		if(rising_edge(Clk)) then
			if(RstB = '0') then
				rState <= stHeader;
			else
				case(rState) IS
					when stHeader =>
						if(rHdCnt = 54) then
							rState <= stData;
						else
							rState <= stHeader;
						end if;
						
					when stData =>
						if(rPxCnt = 786432) then
							rState <= stHeader;
						else
							rState <= stData;
						end if;
				end case;
			end if;
		end if;
	end process u_rState;
End Architecture rtl;