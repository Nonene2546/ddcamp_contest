----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
-- Filename     UserWrDdr.vhd
-- Title        Top
--
-- Company      Design Gateway Co., Ltd.
-- Project      DDCamp
-- PJ No.       
-- Syntax       VHDL
-- Note         

-- Version      1.00
-- Author       B.Attapon
-- Date         2017/12/20
-- Remark       New Creation
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

Entity UserWrDdr Is
	Port
	(
		RstB			: in	std_logic;							-- use push button Key0 (active low)
		Clk				: in	std_logic;							-- clock input 100 MHz

		-- WrCtrl I/F
		MemInitDone		: in	std_logic;
		MtDdrWrReq		: out	std_logic;
		MtDdrWrBusy		: in	std_logic;
		MtDdrWrAddr		: out	std_logic_vector( 28 downto 7 );
		
		-- T2UWrFf I/F
		T2UWrFfRdEn		: out	std_logic;
		T2UWrFfRdData	: in	std_logic_vector( 63 downto 0 );
		T2UWrFfRdCnt	: in	std_logic_vector( 15 downto 0 );
		
		-- UWr2DFf I/F
		UWr2DFfRdEn		: in	std_logic;
		UWr2DFfRdData	: out	std_logic_vector( 63 downto 0 );
		UWr2DFfRdCnt	: out	std_logic_vector( 15 downto 0 )
	);
End Entity UserWrDdr;

Architecture rtl Of UserWrDdr Is

----------------------------------------------------------------------------------
-- Component declaration
----------------------------------------------------------------------------------
	
	
----------------------------------------------------------------------------------
-- Signal declaration
----------------------------------------------------------------------------------
	
	signal	rMemInitDone	: std_logic_vector( 1 downto 0 );
	signal	rMtDdrWrReq		: std_logic;
	signal	rMtDdrWrAddr	: std_logic_vector(28 downto 7);
	
	signal	rDataCnt		: integer range 0 to 31;
	signal	rWrFfWrEn		: std_logic;
	
	type SerStateType Is 
						(
							stInit,
							stIdle,
							stWrite,
							stEnd
						);
						
	signal rState		: SerStateType;
	
Begin

----------------------------------------------------------------------------------
-- Output assignment
----------------------------------------------------------------------------------
	
	T2UWrFfRdEn		<= UWr2DFfRdEn;
	UWr2DFfRdData	<= T2UWrFfRdData;
	UWr2DFfRdCnt	<= T2UWrFfRdCnt;
	
	MtDdrWrReq		<= rMtDdrWrReq;
	MtDdrWrAddr		<= rMtDdrWrAddr;
	
----------------------------------------------------------------------------------
-- DFF 
----------------------------------------------------------------------------------
	
	u_rMemInitDone : Process (Clk) Is
	Begin
		if ( rising_edge(Clk) ) then
			if ( RstB='0' ) then
				rMemInitDone	<= "00";
			else
				-- Use rMemInitDone(1) in your design
				rMemInitDone	<= rMemInitDone(0) & MemInitDone;
			end if;
		end if;
	End Process u_rMemInitDone;
	
	u_rState : Process(Clk) Is
	Begin
		if(rising_edge(Clk)) then
			if(RstB = '0') then
				rState <= stInit;
			else
				case (rState) Is
					when stInit =>
						if(rMemInitDone(1) = '1') then
							rState <= stIdle;
						else
							rState <= stInit;
						end if;
					
					when stIdle =>
						if (MtDdrWrBusy = '1') then
							rState <= stWrite;
						else
							rState <= stIdle;
						end if;
					
					when stWrite =>
						rState <= stEnd;
					
					when stEnd =>
						if (MtDdrWrBusy = '0') then
							rState <= stIdle;
						else
							rState <= stEnd;
						end if;

				end case;
			end if;
		end if;
	end process;
	
	u_rMtDdrWrReq : Process(Clk) Is
	Begin
		if(rising_edge(Clk)) then
			if(RstB = '0') then
				rMtDdrWrReq <= '0';
			elsif(rState = stIdle) then
				rMtDdrWrReq <= '1';
			else
				rMtDdrWrReq <= '0';
			end if;
		end if;
	end process;
	
	u_rMtDdrWrAddr : Process(Clk) Is
	Begin
		if(rising_edge(Clk)) then
			if(RstB = '0') then
				rMtDdrWrAddr(28 downto 7) <= "00" & x"05FE0";
			elsif(rState = stWrite) then
				if(rMtDdrWrAddr(26 downto 7) = 31) then
					if(rMtDdrWrAddr(28 downto 27) = "11") then
						rMtDdrWrAddr(28 downto 27) <= "00";
					else
						rMtDdrWrAddr(28 downto 27) <= rMtDdrWrAddr(28 downto 27) + 1;
					end if;
					
					rMtDdrWrAddr(26 downto 7) <= x"05FE0";
				else
					if(rMtDdrWrAddr(11 downto 7) = 31) then
						rMtDdrWrAddr(26 downto 12) <= rMtDdrWrAddr(26 downto 12) - 1;
						rMtDdrWrAddr(11 downto 7) <= (others => '0');
					else
						rMtDdrWrAddr(11 downto 7) <= rMtDdrWrAddr(11 downto 7) + 1;
					end if;
				end if;
			end if;
		end if;
	end process;
	
End Architecture rtl;