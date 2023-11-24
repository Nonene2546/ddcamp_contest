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
		MtDdrWrReq		: out	std_logic;  -- write request to ddr
		MtDdrWrBusy		: in	std_logic;  -- input from ddr indicate that it has accept request if '1' or ready for new request if '0'
		MtDdrWrAddr		: out	std_logic_vector( 28 downto 7 ); -- ddr address you want to write on
		
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
	signal	rMtDdrWrReq		: std_logic; -- Memory write request signal
	signal	rMtDdrWrAddr	: std_logic_vector(28 downto 7); -- Memory write address signal
	
	signal	rDataCnt		: std_logic_vector(5 downto 0); -- Data counter for address generation
	signal	rWrFfWrEn		: std_logic; -- Write enable for the FIFO write operation
	
	type SerStateType Is 
						(
							stInit,   -- Memory initialization state
							stReq,    -- Request state (Request write then wait for ddr to accept request -> MtDdrWrBusy = '1')
							stAddr,   -- Changing the address
							stEnd     -- End state (Wait for ddr ready for a new request -> MtDdrWrBusy = '0')
						);
						
	signal rState		: SerStateType; -- State variable
	
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
				rState <= stInit; -- Reset state machine on active-low reset
			else
				case (rState) Is
					when stInit =>
						if(rMemInitDone(1) = '1') then
							rState <= stReq; -- Transition to idle state after memory initialization
						else
							rState <= stInit; -- Stay in initialization state otherwise
						end if;
					
					when stReq =>
						if (MtDdrWrBusy = '1') then
							rState <= stAddr; -- Transition to address state if MtDdrWrBusy = '1' (ddr has accept request)
						else
							rState <= stReq; -- Stay in idle state otherwise
						end if;
					
					when stAddr =>
						rState <= stEnd;
					
					when stEnd =>
						if (MtDdrWrBusy = '0') then
							rState <= stReq; -- Transition back to idle state when ddr read is ready for a new request
						else
							rState <= stEnd; -- Stay in end state otherwise
						end if;

				end case;
			end if;
		end if;
	end process;
	
	u_rMtDdrWrReq : Process(Clk) Is
	Begin
		if(rising_edge(Clk)) then
			if(RstB = '0') then
				rMtDdrWrReq <= '0'; -- Clear memory write request on active-low reset
			elsif(rState = stReq) then
				rMtDdrWrReq <= '1'; -- Set memory write request in request state
			else
				rMtDdrWrReq <= '0'; -- Clear memory write request otherwise
			end if;
		end if;
	end process;
	
	u_rMtDdrWrAddr : Process(Clk) Is
	Begin
		if(rising_edge(Clk)) then
			if(RstB = '0') then
				rMtDdrWrAddr(28 downto 7) <= "00" & x"05FE0"; -- Initialize memory write address on active-low reset
			elsif(rState = stAddr) then
				if(rMtDdrWrAddr(26 downto 7) = 31) then -- If address has reach the end
					if(rMtDdrWrAddr(28 downto 27) = "11") then
						rMtDdrWrAddr(28 downto 27) <= "00"; -- If it has write all 4 picture, Reset address to picture no.0
					else
						rMtDdrWrAddr(28 downto 27) <= rMtDdrWrAddr(28 downto 27) + 1; -- If not, Increment the picture no.
					end if;
					
					rMtDdrWrAddr(26 downto 7) <= x"05FE0"; -- Reset lower bits of write address
				else
					if(rMtDdrWrAddr(11 downto 7) = 31) then
						rMtDdrWrAddr(26 downto 12) <= rMtDdrWrAddr(26 downto 12) - 1; -- Decrement the row
						rMtDdrWrAddr(11 downto 7) <= (others => '0'); -- Reset the column
					else
						rMtDdrWrAddr(11 downto 7) <= rMtDdrWrAddr(11 downto 7) + 1; -- Increment the column
					end if;
				end if;
			end if;
		end if;
	end process;
	
End Architecture rtl;