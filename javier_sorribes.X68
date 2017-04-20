*-----------------------------------------------------------
* Title      : Monitor Design Project
* Written by : Javier Sorribes
* Date       : 4/2/17
* Description: Some crazy, crazy stuff
*-----------------------------------------------------------
*** MEMORY INITIALIZATION ***
    ORG     $1000       ; stack and other memory
; $A is newline, $D carriage return, $20 whitespace
WELCOME     DC.B    'WELCOME TO MONITOR441! - BY JAVIER SORRIBES',0
PROMPT_STR  DC.B    $A,$D,'MONITOR441>',0 ; might want to add one space
INVALID_MSG DC.B    'INVALID COMMAND',$A,$D
            DC.B    'Type HELP for command usage',0

COM_TABL    DC.B    '4HELP',0   ; Command names table
            DC.B    '4MDSP',$20  ; number specifies length of word 
            DC.B    '5SORTW',$20    ; used for SEARCH (not input)
            DC.B    '2MM',0
            DC.B    '2DF',0
            DC.B    '4EXIT',0
            DC.B    '4CONV',$20
            
COM_ADDR    DC.W    HELP        ; Command addresses table
            DC.W    MDSP
            DC.W    SORTW
            DC.W    MM
            DC.W    DF
            DC.W    EXIT
            DC.W    CONV
            
HELP_MSG    DC.B    'HELP: Displays This Message',$A,$A,$D
            DC.B    'MDSP: Outputs Address And Memory Contents',$A,$D
            DC.B    'Default address2: address1 + 16',$A,$D
            DC.B    'MDSP <address1>[ <address2>] eg: MDSP $908 $904<CR>',$A,$A,$D
            DC.B    'SORTW: Sorts Unsigned Words In A Memory Block',$A,$D
            DC.B    'Both address1 and address2 are inclusive',$A,$D
            DC.B    'Default order: descending',$A,$D
            DC.B    'SORTW <address1> <address2>[ A|D] eg: SORTW $2000 $201E A<CR>',$A,$A,$D
            DC.B    'MM: Modifies Data In Memory',$A,$D
            DC.B    'Default: Displays one byte',$A,$D
            DC.B    'W: Displays one word',$A,$D
            DC.B    'L: Displays one long word',$A,$D
            DC.B    'MM <address>[ size]',$A,$A,$D
            ** Add all others as I go
            DC.B    'DF: Displays All Formatted Registers eg: DF<CR>',$A,$A,$D
            DC.B    'EXIT: Exit The Monitor Program eg: EXIT<CR>',$A,$A,$D
            DC.B    'CONV: Convert Hex to Decimal, Or Vice Versa',$A,$D
            DC.B    'CONV [$]num eg: CONV 16<CR> returns $10',0
            
DF_MSG      DC.B    $D,0    ; erase whatever had been printed on that line
            DC.B    'D0=',0,'XXXXXXXX',0,' D1=',0,'XXXXXXXX',0,' D2=',0,'XXXXXXXX',0,' D3=',0,'XXXXXXXX',$A,$D,0
            DC.B    'D4=',0,'XXXXXXXX',0,' D5=',0,'XXXXXXXX',0,' D6=',0,'XXXXXXXX',0,' D7=',0,'XXXXXXXX',$A,$D,0
            DC.B    'A0=',0,'XXXXXXXX',0,' A1=',0,'XXXXXXXX',0,' A2=',0,'XXXXXXXX',0,' A3=',0,'XXXXXXXX',$A,$D,0
            DC.B    'A4=',0,'XXXXXXXX',0,' A5=',0,'XXXXXXXX',0,' A6=',0,'XXXXXXXX',0,' A7=',0,'XXXXXXXX',$A,$D,0
            
*** RUNNING PROGRAM ***
    ;ORG     $1200 --> allow for as much as necessary before this, and add program right after it
START:                  ; first instruction of program

MAX_IN_LEN  EQU 80  ; to ensure input won't overflow stack
STACK       EQU $2FFC   ; $3000 minus a long word because A7 will be stored first
        MOVE.L  A7,STACK    ; store original location of stack beforehand
        LEA     STACK,A7
        MOVEM.L D0-D7/A0-A6,-(A7)   ; store all registers in stack. Want to be able to restore them

** Populate exception vector table ***
        MOVE.L  #BERR,$8
        
*** MAIN: Prompt, execute and repeat ***
        LEA     WELCOME,A1
        MOVE.B  #13,D0
        TRAP    #15     ; display welcome message
        SUBA.L  #MAX_IN_LEN,A7  ; open space in stack for input (do only once)
PROMPT  LEA     PROMPT_STR,A1  
        MOVE.B  #14,D0
        TRAP    #15     ; print out prompt
        MOVEA.L A7,A1   ; input will go in stack
        MOVE.B  #2,D0
        TRAP    #15     ; read user input, length stored in D1
        
        LEA     COM_TABL,A4 ; beginning of command table
        LEA     COM_ADDR,A5 ; end of command table
        CLR.L   D3      ; will be the count of where the command is
SEARCH  CLR.L   D2
        MOVE.B  (A4)+,D2   ; length of next command string
        SUBI.B  #$30,D2 ; convert ascii num to hex
        MOVEA.L A1,A6   ; pointer to input string
CMP_B   CMPM.B  (A4)+,(A6)+ ; compare byte to byte with command names
        DBNE    D2,CMP_B    ; keep comparing characters until length is over
        TST.W   D2
        BLT     EXEC    ; loop was exhausted and all chars were equal
        ADDA.L  D2,A4   ; go to end of command
        ADDQ.L  #2,D3   ; else, increment offset by word size
        CMPA.L  A4,A5 ; end of COM_TABL
        BGE     SEARCH  ; keep on searching
        
        BSR     INVALID ; print invalid command message
        BRA     PROMPT ; prompt again
        
EXEC    ADDA.L  D3,A5   ; add offset to COM_ADDR start
        MOVEA.L #0,A3   ; clear A3, used for subroutine call
        MOVEA.W (A5),A3 ; move that command's address to register
        JSR     (A3)    ; jump to that command's subroutine (below)

        BRA     PROMPT  ; prompt again

*** DEBUGGING COMMANDS ***
* HELP -- displays help message
HELP    MOVEM.L D0/A1,-(A7) ; store used registers in stack
        LEA     HELP_MSG,A1  
        MOVE.B  #13,D0
        TRAP    #15     ; print help message
        MOVEM.L (A7)+,D0/A1 ; restore registers from stack
        RTS
        
* For this subroutine and others, A6 contains the start of the command's parameters
* eg: MDSP $1230 $1890 <- A6 points to the first '$'

* MDSP -- displays memory block
MDSP    MOVEM.L D0-D4/A1-A4,-(A7)
        MOVE.B  (A6)+,D1    ; first '$'
        CMPI.B  #$24,D1 ; is it '$'?
        BNE     MDSPINV ; wrong command usage
        BSR     MEM2HEX ; D1 has 1st address in hex
        MOVEA.L D1,A2   ;store in A2
        MOVE.B  (A6)+,D1    ; space in between addresses
        TST.B   D1  ; if null, no 2nd address, so address2 = address1 + 16
        BNE     MDSPADDR2
        MOVEA.L A2,A3
        ADDA.L  #16,A3  ; A3 = A2 +16
        BRA     MDSPLOOP
MDSPADDR2   MOVE.B  (A6)+,D1    ; second '$'
        CMPI.B  #$24,D1
        BNE     MDSPINV
        BSR     MEM2HEX ; D1 has 2nd address in hex
        MOVEA.L D1,A3
MDSPLOOP    MOVEA.L A7,A1
        SUBA.L  #$40,A1 ; move A1 far from A7 to avoid collision in subroutines
        MOVE.B  #$00,-(A1) ; null terminator
        MOVE.B  #$20,-(A1)  ; space
        MOVE.B  #$3E,-(A1)  ; '<' for nicer output
        MOVE.L  A2,D1
        BSR     HEX2MEM ; puts digits of D1 into -X(A1) in ascii (no trailing zeros)
        MOVE.B  #$24,-(A1)  ; '$' for nicer output
        MOVE.B  #14,D0
        TRAP    #15     ; print current memory address
        MOVE.B  #$00,-(A1) ; null terminator
        MOVE.B  #$20,-(A1)  ; space
        MOVE.L  (A2)+,D1
        MOVEA.L A1,A4   ; old value of A1
        BSR     HEX2MEM ; puts digits of D1 into -X(A1) in ascii (no trailing zeros)
        SUBA.L  A1,A4   ; difference
        MOVE.L  A4,D4   ; D4 counter to add trailing zeros
MDSPZEROS CMP.L   #8,D4
        BGE     MDSPPRINT
        MOVE.B  #$30,-(A1)
        ADDQ.L  #1,D4
        BRA     MDSPZEROS
MDSPPRINT   MOVE.B  #13,D0
        TRAP    #15
        CMPA.L  A2,A3
        BGT     MDSPLOOP
        BRA     MDSPDONE
MDSPINV BSR     INVALID ; print invalid command message
MDSPDONE    MOVEM.L (A7)+,D0-D4/A1-A4
        RTS

* SORTW -- implements bubble sort (unsigned numbers)
SORTW   MOVEM.L D0-D4/A1-A4,-(A7)
        MOVE.B  (A6)+,D1    ; first '$'
        CMPI.B  #$24,D1     ; is it '$'?
        BNE     SORTWINV    ; wrong command usage
        BSR     MEM2HEX     ; D1 has 1st address in hex
        MOVEA.L D1,A2       ; store in A2
        MOVE.B  (A6)+,D1    ; space in between addresses
        CMPI.B  #$20,D1     ; is it ' '?
        BNE     SORTWINV    ; wrong command usage
        MOVE.B  (A6)+,D1    ; second '$'
        CMPI.B  #$24,D1     ; is it '$'?
        BNE     SORTWINV    ; wrong command usage
        BSR     MEM2HEX     ; D1 has now the 2nd address
        MOVEA.L D1,A3       ; store in A3
        MOVE.B  (A6)+,D1    ; space 
        CMPI.B  #$00,D1     ; is it NULL?
        BEQ     SORTWDEF    ; use default: descending (D1=0)
        CMPI.B  #$20,D1     ; or is it ' '?
        BNE     SORTWINV    ; wrong command usage
        MOVE.B  (A6)+,D1    ; char either 'A' or 'D'
        CMPI.B  #$41,D1     ; is it 'A'?
        BEQ     SORTWLOOP   ; if so, D1 marks ascending
        CMPI.B  #$44,D1     ; else, is it 'D'?
        BNE     SORTWINV    ; if it isn't, input was invalid
SORTWDEF    CLR.L   D1          ; if it is, D1=0 marks descending
SORTWLOOP   MOVEA.L A2,A4   ; first address copied into A4
SORTWCMP    TST.B   D1      ; tells us whether ascending or descending
        BEQ     SORTWD  ; do descending
SORTWA  CMP.W   (A4)+,(A4)+ ; compare next two numbers
        BCS     SORTWSWAP   ; swap if not in ascending order (if 1st>2nd)
        BRA     SORTWNEXT   ; otherwise, move on
SORTWD  CMP.W   (A4)+,(A4)+ ; compare next two numbers
        BHI     SORTWSWAP   ; swap if not in descending order (if 2nd>1st)
SORTWNEXT   SUBQ.L  #2,A4   ; look back at previous number
        CMP.L   A4,A3       
        BNE     SORTWCMP    ; keep comparing if not at end yet (A3 inclusive)
        BRA     SORTWDONE   ; else, done
SORTWSWAP MOVE.L  -(A4),D4   ; move both words to register
        SWAP.W  D4  ; swap the two words 
        MOVE.L  D4,(A4) ; write them back
        BRA     SORTWLOOP   ; loop again from start
SORTWINV    BSR INVALID
SORTWDONE   MOVEM.L (A7)+,D0-D4/A1-A4
        RTS

* MM -- 
MM    
        RTS
        
* DF -- displays formatted registers
DF      MOVEM.L D0-D1/A0-A1,-(A7)
        LEA     STACK,A0
        SUBA.L  #120,A0
        SUBA.L  #MAX_IN_LEN,A0
        LEA     DF_MSG,A1
        MOVE    #14,D0
        TRAP    #15     ; print carriage return
        MOVE.L  #15,D1  ; number of registers - 1 to print
DFLOOP  TRAP    #15     ; print register name
        MOVE.L  (A0)+,A1    ; put register value in A1
        TRAP    #15     ; print register value
        DBT     D1,DFLOOP
        MOVEM.L (A7)+,D0-D1/A0-A1
        RTS

* EXIT -- terminates the program
EXIT    ADDA.L  #4,A7   ; move past the PC stored in the stack
        ADDA.L  #MAX_IN_LEN,A7  ; move stack back to position prior to reading input
        MOVEM.L (A7)+,D0-D7/A0-A6   ; restore all registers in stack
        MOVEA.L STACK,A7
        BRA     END     ; exit program
        
* The 2 extra commands:
* CONV -- takes in hex and returns decimal, or viceversa
CONV    MOVEM.L D0-D1/A1,-(A7)
        MOVE.B  (A6)+,D1
        CMPI.B  #$24,D1 ; is it '$'?
        BEQ     CONVH2D ; if so, hex to dec
CONVD2H SUBQ.L  #1,A6   ; point back at first number
        BSR     MEM2DEC ; D1 contains the decimal number
        MOVEA.L A6,A1   ; number ready to print
        BSR     HEX2MEM ; that number is written as hex in memory
        MOVE.B  #'$',-(A1)
        BRA     CONVDONE
CONVH2D BSR     MEM2HEX ; convert ascii to hex
        MOVEA.L A6,A1   ;number ready to print
        BSR     DEC2MEM ; convert it back to ascii but as decimal
CONVDONE MOVE.B #13,D0
        TRAP    #15 ; print result
        MOVEM.L (A7)+,D0-D1/A1
        RTS

*** HELPERS ***
* Print INVALID message:
INVALID MOVEM.L D0/A1,-(A7)
        LEA     INVALID_MSG,A1  ; command was invalid
        MOVE.B  #13,D0
        TRAP    #15     ; output invalid command
        MOVEM.L (A7)+,D0/A1
        RTS

* Takes X digits from (A6) in ascii and puts them in D1 as hex:
MEM2HEX MOVEM.L D0/D7,-(A7)    ; store in stack
        CLR.L   D1
        MOVE.B (A6)+,D7    ; read in next byte (prime read)
        CMPI.B  #$30,D7
        BLT     M2HDONE ; reached some whitespace or non-numeric ascii
M2HNEXT BSR     ASCII2NUM   ; byte to hex digit, in D7
        ADD.B   D7,D1
        MOVE.B (A6)+,D7    ; read in next byte (prime read)
        CMPI.B  #$30,D7
        BLT     M2HDONE ; reached some whitespace or non-numeric ascii
        ASL.L   #4,D1   ; skip this the last time
        BRA     M2HNEXT ; loop again because not done
M2HDONE SUBA.L #1,A6   ; leave A6 pointing at byte immediately after last number
        MOVEM.L (A7)+,D0/D7    ; restore from stack
        RTS

* Takes byte in ascii in D7 and converts it to digit in D7:
* Assumes 0-9 or A-F
ASCII2NUM   CMPI.B #$40,D7
        BLT A2NSKIPPY
        SUBQ.B  #$7,D7   ; only for A-F
A2NSKIPPY   SUB.B   #$30,D7
        RTS
        
* Takes digits from D1 in hex and puts them into -X(A1) in ascii (no trailing zeros):
HEX2MEM MOVEM.L D0/D2/D7,-(A7)    ; store in stack
        CLR.L   D0   ; counter
H2MNEXT MOVE.L  D1,D7
        MOVE.L D0,D2
H2MRIGHT    SUBQ.W  #1,D2
        BLT     H2MDONE
        LSR.L   #4,D7   ; that upper byte to lowest by -> only one left
        BRA     H2MRIGHT
H2MDONE TST.L   D7
        BEQ     H2MEND      ; if number done
        BSR     NUM2ASCII   ; convert to ascii in D7
        MOVE.B  D7,-(A1)
        ADDQ.W  #1,D0
        CMPI.W  #8,D0
        BLT     H2MNEXT
H2MEND  MOVEM.L (A7)+,D0/D2/D7
        RTS

* Takes digit in D7 and converts it to ascii byte in D7:
* Assumes 0-9 or A-F
NUM2ASCII   AND.L  #$0F,D7 ; mask and take only smallest hex digit
        CMPI.B  #$A,D7
        BLT N2ASKIPPY
        ADDQ.B  #$7,D7   ; only for A-F
N2ASKIPPY   ADD.B   #$30,D7
        RTS
        
* Takes X digits from (A6) in ascii and puts them in D1 as dec:
MEM2DEC MOVEM.L D0/D7,-(A7)    ; store in stack
        CLR.L   D1
        MOVE.B (A6)+,D7    ; read in next byte (prime read)
        CMPI.B  #$30,D7
        BLT     M2DDONE ; reached some whitespace or non-numeric ascii
M2DNEXT BSR     ASCII2NUM   ; byte to hex digit, in D7
        ADD.B   D7,D1
        MOVE.B (A6)+,D7    ; read in next byte (prime read)
        CMPI.B  #$30,D7
        BLT     M2DDONE ; reached some whitespace or non-numeric ascii
        MULU    #10,D1   ; skip this the last time
        BRA     M2DNEXT ; loop again because not done
M2DDONE  SUBA.L #1,A6   ; leave A6 pointing at byte immediately after last number
        MOVEM.L (A7)+,D0/D7    ; restore from stack
        RTS

* Takes number from D1 in dec and puts them into -X(A1) in ascii:
DEC2MEM MOVEM.L D2/D7,-(A7)    ; store in stack
        MOVE.L  D1,D2
D2MLOOP DIVU    #10,D2
        MOVE.L  D2,D7
        SWAP.W  D7
        BSR     NUM2ASCII
        MOVE.B  D7,-(A1)
        AND.L   #$0000FFFF,D2 ; make sure we use only word in next divisions
        TST.W   D2
        BNE     D2MLOOP
        MOVEM.L (A7)+,D2/D7
        RTS
        
*** EXCEPTION HANDLERS ***
BERR    BSR     INVALID
        BSR     INVALID
        LEA     STACK,A7
        SUBA.L  #120,A7
        SUBA.L  #MAX_IN_LEN,A7
        BRA     PROMPT

END
    END     START        ; last line of source












*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
