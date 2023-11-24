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
        RstB            : in    std_logic;                          -- Active-low reset
        Clk             : in    std_logic;                          -- Clock

        -- RX input
        RxWrData        : in    std_logic_vector(7 downto 0);       -- RX write data
        RxWrEn          : in    std_logic;                          -- RX write enable
        
        -- HDMI Data Interface
        HDMIFfWrEn      : out   std_logic;                          -- FIFO write enable
        HDMIFfWrData    : out   std_logic_vector( 23 downto 0 );    -- FIFO write data
        HDMIFfWrCnt     : in    std_logic_vector( 7 downto 0 )      -- FIFO write count
    );
End Entity BitmapPattern;

Architecture rtl Of BitmapPattern Is

----------------------------------------------------------------------------------
-- Constant Declaration
----------------------------------------------------------------------------------
    -- No constants declared for this architecture

----------------------------------------------------------------------------------
-- Signal declaration
----------------------------------------------------------------------------------
    
    type SerStateType is 
                        (
                            stHeader,  -- Header state (discard the header)
                            stData     -- Data state (pixelate and send the data from rx to FIFO)
                        );
                        
    signal  rState          : SerStateType;                         -- State variable
    
    signal  rHDMIFfWrEn     : std_logic;                           -- FIFO write enable signal
    signal  rBitMap         : std_logic_vector(23 downto 0);       -- Bitmap data (pixel)
    
    signal  rHdCnt          : std_logic_vector(5 downto 0);       -- Header count
    signal  rRGBCnt         : std_logic_vector(1 downto 0);       -- RGB count
    signal  rPxCnt          : std_logic_vector(19 downto 0);      -- Pixel count
    
Begin

----------------------------------------------------------------------------------
-- Output assignment
----------------------------------------------------------------------------------
    
    HDMIFfWrEn                  <= rHDMIFfWrEn;                  
    HDMIFfWrData(23 downto 0)   <= rBitMap(23 downto 0);         
    
----------------------------------------------------------------------------------
-- DFF 
----------------------------------------------------------------------------------
    
    u_rHdCnt : Process(Clk) IS
    Begin
        if (rising_edge(Clk)) then
            if (RstB = '0') then
                rHdCnt(5 downto 0) <= (others => '0');                          -- Reset header count on active-low reset
            else
                if (rState = stHeader) then
                    if (RxWrEn = '1') then
                        rHdCnt(5 downto 0) <= rHdCnt(5 downto 0) + 1;                       -- Increment header count on RX write enable
                    else
                        rHdCnt(5 downto 0) <= rHdCnt(5 downto 0);
                    end if;
                else
                    rHdCnt(5 downto 0) <= (others => '0');                     -- Clear header count in data state
                end if;
            end if;
        end if;
    end process u_rHdCnt;
    
    u_rRGBCnt : Process(Clk) IS
    Begin
        if (rising_edge(Clk)) then
            if (RstB = '0') then
                rRGBCnt(1 downto 0) <= "00";                                   -- Reset RGB count on active-low reset
            else
                if (rRGBCnt(1 downto 0) = "11" or rState = stHeader) then
                    rRGBCnt(1 downto 0) <= "00";                               -- Reset RGB count in header state or when complete pixel
                elsif (RxWrEn = '1') then
                    rRGBCnt(1 downto 0) <= rRGBCnt(1 downto 0) + 1;                        -- Increment RGB count on RX write enable
                else
                    rRGBCnt(1 downto 0) <= rRGBCnt(1 downto 0);
                end if;
            end if;
        end if;
    end Process u_rRGBCnt;
    
    u_rPxCnt : Process(Clk) IS
    Begin
        if (rising_edge(Clk)) then
            if (RstB = '0') then
                rPxCnt(19 downto 0) <= (others => '0');                         -- Reset pixel count on active-low reset
            else
                if (rPxCnt(19 downto 0) = 786432) then
                    rPxCnt(19 downto 0) <= (others => '0');                     -- Reset pixel count when reaching the last pixel value
                elsif (rHDMIFfWrEn = '1') then
                    rPxCnt(19 downto 0) <= rPxCnt(19 downto 0) + 1;                          -- Increment pixel count when send pixel to FIFO
                else
                    rPxCnt(19 downto 0) <= rPxCnt(19 downto 0);
                end if;    
            end if;
        end if;
    end Process u_rPxCnt;
    
    u_rBitMap : Process(Clk) IS
    Begin
        if (rising_edge(Clk)) then
            if (RstB = '0') then
                rBitMap <= (others => '0');                        -- Reset bitmap data on active-low reset
            elsif (RxWrEn = '1') then
                rBitMap(23 downto 0) <= RxWrData(7 downto 0) & rBitMap(23 downto 8);  -- Shift in RX write data to the bitmap
            else
                rBitMap <= rBitMap;
            end if;    
        end if;
    end Process u_rBitMap;
    
    u_rHDMIFfWrEn : Process (Clk) is
    Begin
        if (rising_edge(Clk)) then
            if (RstB='0') then
                rHDMIFfWrEn <= '0';                               -- Clear HDMI FIFO write enable on active-low reset
            else
                if (rRGBCnt(1 downto 0) = "11") then
                    rHDMIFfWrEn <= '1';                            -- Set HDMI FIFO write enable when complete pixel
                else
                    rHDMIFfWrEn <= '0';
                end if;
            end if;
        end if;
    end Process u_rHDMIFfWrEn;
    
    u_rState : Process(Clk) is
    Begin
        if (rising_edge(Clk)) then
            if (RstB = '0') then
                rState <= stHeader;                               -- Set state to header on active-low reset
            else
                case (rState) is
                    when stHeader =>
                        if (rHdCnt(5 downto 0) = 54) then
                            rState <= stData;                   -- Transition to data state after discard all headers
                        else
                            rState <= stHeader;
                        end if;
                        
                    when stData =>
                        if (rPxCnt = 786432) then
                            rState <= stHeader;                 -- Transition to header state after reaching the last pixel
                        else
                            rState <= stData;
                        end if;
                end case;
            end if;
        end if;
    end process u_rState;
End Architecture rtl;
