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
GOODBYE     DC.B    'THANK YOU FOR USING MONITOR441, SEE YOU SOON!',0
PROMPT_STR  DC.B    $A,$D,'MONITOR441>',0 ; might want to add one space
INVALID_MSG DC.B    'INVALID COMMAND',$A,$D
            DC.B    'Type HELP for command usage',0

COM_TABL    DC.B    '4HELP',0   ; Command names table
            DC.B    '4MDSP',$20  ; number specifies length of word 
            DC.B    '5SORTW',$20    ; used for SEARCH (not input)
            DC.B    '2MM',$20
            DC.B    '2MS',$20
            DC.B    '2BF',$20
            DC.B    '4BMOV',$20
            DC.B    '4BTST',$20
            DC.B    '2GO',$20
            DC.B    '2DF',0
            DC.B    '4EXIT',0
            DC.B    '4CONV',$20
            
COM_ADDR    DC.W    HELP        ; Command addresses table
            DC.W    MDSP
            DC.W    SORTW
            DC.W    MM
            DC.W    MS
            DC.W    BF
            DC.W    BMOV
            DC.W    BTST
            DC.W    GO
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
            DC.B    'MS: Set Memory To Given ASCII Or Hex',$A,$D
            DC.B    'Default: ASCII. Prepend $ for hex (byte, word or long)',$A,$D
            DC.B    'MS <address1> [$]<string|hex> eg: MS $4000 Hello!',$A,$A,$D
            DC.B    'BF: Fills Block Of Memory With Word Pattern',$A,$D
            DC.B    'Both addresses must be even',$A,$D
            DC.B    'Default pattern: 0000',$A,$D
            DC.B    'If less than 4 digits given, right justified and zero padded',$A,$D
            DC.B    'BF <address1> <address2>[ pattern] eg: BF $2000 $2200 4325<CR>',0
HELP_MSG2
            ** Add all others as I go
            DC.B    'BMOV: Duplicate A Memory Block At Another Address',$A,$D
            DC.B    'Must provide two addresses (inclusive, exclusive) for first block',$A,$D
            DC.B    'Only one address (inclusive start) for second block',$A,$D
            DC.B    'BMOV <address1.1> <address1.2> <address2>',$A,$A,$D
            DC.B    'BTST: Test Memory Block',$A,$D
            DC.B    'BTST <address1> <address2>',$A,$A,$D
            DC.B    'GO: Execute Another Program',$A,$D
            DC.B    'GO <address1>',$A,$A,$D
            DC.B    'DF: Displays All Formatted Registers eg: DF<CR>',$A,$A,$D
            DC.B    'EXIT: Exit The Monitor Program eg: EXIT<CR>',$A,$A,$D
            DC.B    'CONV: Convert Hex to Decimal, Or Vice Versa',$A,$D
            DC.B    'CONV [$]num eg: CONV 16<CR> returns $10',0
            
DF_MSG      DC.B    'D0=XXXXXXXX D1=XXXXXXXX D2=XXXXXXXX D3=XXXXXXXX',$A,$D
            DC.B    'D4=XXXXXXXX D5=XXXXXXXX D6=XXXXXXXX D7=XXXXXXXX',$A,$D
            DC.B    'A0=XXXXXXXX A1=XXXXXXXX A2=XXXXXXXX A3=XXXXXXXX',$A,$D
            DC.B    'A4=XXXXXXXX A5=XXXXXXXX A6=XXXXXXXX A7=XXXXXXXX',0
DF_MSG_END
         
ADDRERR_MSG DC.B    $D,'Address Error Exception',0   
BERR_MSG    DC.B    $D,'Bus Error Exception',0
ILLINS_MSG  DC.B    $D,'Illegal Instructor Exception',0
PRIVERR_MSG DC.B    $D,'Privilege Error Exception',0
DIV0_MSG    DC.B    $D,'Division By Zero Exception',0
CHKERR_MSG  DC.B    $D,'Check Exception',0
LINEA_MSG   DC.B    $D,'Line A Exception',0
LINEF_MSG   DC.B    $D,'Line F Exception',0
            
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
        MOVE.L  #ADDRERR,$C
        MOVE.L  #ILLINS,$10
        MOVE.L  #DIV0,$14
        MOVE.L  #CHKERR,$18
        MOVE.L  #PRIVERR,$20
        MOVE.L  #LINEA,$28
        MOVE.L  #LINEF,$2C
        
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
HELP    MOVEM.L D0-D1/A1,-(A7) ; store used registers in stack
        LEA     HELP_MSG,A1  
        MOVE.B  #13,D0
        TRAP    #15     ; print first part of the help message
        MOVE.B  #5,D0
        TRAP    #15     ; wait for the user to enter a character
        LEA     HELP_MSG2,A1
        MOVE.B  #13,D0
        TRAP    #15     ; print second half of the message
        MOVEM.L (A7)+,D0-D1/A1 ; restore registers from stack
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
        MOVE.B  #$3E,-(A1)  ; '>' for nicer output
        MOVE.L  A2,D1   ; memory address into D1
        BSR     HEX2MEM ; puts digits of D1 into -X(A1) in ascii (no trailing zeros)
        MOVE.B  #$24,-(A1)  ; '$' for nicer output
        MOVE.B  #14,D0
        TRAP    #15     ; print current memory address
        MOVE.B  #$00,-(A1)  ; null terminator
        MOVE.L  (A2)+,D1    ; memory value into D1
        BSR     HEX2MEM ; puts digits of D1 into -X(A1) in ascii (no trailing zeros)
        MOVE.B  #13,D0
        TRAP    #15     ; print
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

* MM -- modifies data in memory. Size can be B, W or L
MM      MOVEM.L D0-D1/A0-A1,-(A7)
        MOVEA.L A6,A1   ; A1 used for I/O later
        MOVE.B  (A6)+,D1    ; '$'
        CMPI.B  #$24,D1 ; is it '$'?
        BNE     INVALID ; wrong command usage
        BSR     MEM2HEX ; D1 has address in hex
        MOVEA.L D1,A0   ;store in A0
        MOVE.B  (A6)+,D1    ; ' ' before option
        CMPI.B  #0,D1       ; is it null?
        BEQ     MMBYTE  ; use default: byte
        CMPI.B  #$20,D1 ; is it ' '?
        BNE     INVALID ; wrong command usage
        MOVE.B  (A6)+,D1    ; the option
        CMPI.B  #'B',D1
        BEQ     MMBYTE
        CMPI.B  #'W',D1
        BEQ     MMWORD
        CMPI.B  #'L',D1
        BEQ     MMLONG
        BRA     MMINV   ; wrong option
MMBYTE  ADDA.L  #14,A1  ; output will be 13 chars long + null
        MOVE.B  #0,-(A1)    ; null terminator
        MOVE.B  #'?',-(A1)  ; nicer output
        CLR.L   D1
        MOVE.B  (A0),D1     ; content of memory to D1
        BSR     HEX2MEM     ; writes memory content to -8(A1)
        ADDA.L  #6,A1       ; we only want 2 chars, not 8
        MOVE.B  #$9,-(A1)   ; a tabspace
        MOVE.L  A0,D1       ; memory address
        BSR     HEX2MEM     ; memory address to -8(A1)
        MOVE.B  #'$',-(A1)  ; nicer output
        MOVE.B  #14,D0
        TRAP    #15         ; print
        MOVE.B  #2,D0
        TRAP    #15         ; read new value, if any
        CMPI.B  #0,(A1)
        BNE     MMBNEXT     ; skip memory address?
        ADDA.L  #1,A0       ; if yes, increment A0
        BRA     MMBYTE      ; ...and loop
MMBNEXT CMPI.B  #'.',(A1)   ; else, check if done (entered '.')
        BEQ     MMDONE
        MOVEA.L A1,A6       ; new value to write in!
        BSR     MEM2HEX     ; store input value from A6 in D1
        MOVE.B  D1,(A0)+    ; put it in address location
        BRA     MMBYTE      ; and loop!
MMWORD  ADDA.L  #16,A1  ; output will be 15 chars long + null
        MOVE.B  #0,-(A1)
        MOVE.B  #'?',-(A1)
        CLR.L   D1
        MOVE.W  (A0),D1
        BSR     HEX2MEM     ; writes memory content to -8(A1)
        ADDA.L  #4,A1       ; we only want 4 chars, not 8
        MOVE.B  #$9,-(A1)   ; a tabspace
        MOVE.L  A0,D1
        BSR     HEX2MEM     ; memory address to -8(A1)
        MOVE.B  #'$',-(A1)
        MOVE.B  #14,D0
        TRAP    #15         ; print
        MOVE.B  #2,D0
        TRAP    #15         ; read new value, if any
        CMPI.B  #0,(A1)
        BNE     MMWNEXT     ; skip memory address?
        ADDA.L  #2,A0       ; if yes, increment A0
        BRA     MMWORD      ; ...and loop
MMWNEXT CMPI.B  #'.',(A1)   ; else, check if done (entered '.')
        BEQ     MMDONE
        MOVEA.L A1,A6       ; new value to write in!
        BSR     MEM2HEX     ; store input value from A6 in D1
        MOVE.W  D1,(A0)+    ; put it in address location
        BRA     MMWORD      ; and loop!
MMLONG  ADDA.L  #20,A1  ; output will be 19 chars long + null
        MOVE.B  #0,-(A1)
        MOVE.B  #'?',-(A1)
        CLR.L   D1
        MOVE.L  (A0),D1
        BSR     HEX2MEM     ; writes memory content to -8(A1)
        MOVE.B  #$9,-(A1)   ; a tabspace
        MOVE.L  A0,D1
        BSR     HEX2MEM     ; memory address to -8(A1)
        MOVE.B  #'$',-(A1)
        MOVE.B  #14,D0
        TRAP    #15         ; print
        MOVE.B  #2,D0
        TRAP    #15         ; read new value, if any
        CMPI.B  #0,(A1)
        BNE     MMLNEXT     ; skip memory address?
        ADDA.L  #4,A0       ; if yes, increment A0
        BRA     MMLONG      ; ...and loop
MMLNEXT CMPI.B  #'.',(A1)   ; else, check if done (entered '.')
        BEQ     MMDONE
        MOVEA.L A1,A6       ; new value to write in!
        BSR     MEM2HEX     ; store input value from A6 in D1
        MOVE.L  D1,(A0)+    ; put it in address location
        BRA     MMLONG      ; and loop!
MMINV   BSR     INVALID
MMDONE  MOVEM.L (A7)+,D0-D1/A0-A1
        RTS
        
* MS -- store ascii (including null terminator) or hex in memory
MS      MOVEM.L D1/A1,-(A7)
        MOVE.B  (A6)+,D1    ; first '$'
        CMPI.B  #$24,D1     ; is it '$'?
        BNE     MSINV    ; wrong command usage
        BSR     MEM2HEX     ; D1 has 1st address in hex
        MOVEA.L D1,A1       ; store in A1
        MOVE.B  (A6)+,D1
        CMPI.B  #$20,D1     ; is it ' '?
        BNE     MSINV   ; wrong command usage
        MOVE.B  (A6)+,D1
        CMPI.B  #$24,D1     ; '$'?
        BEQ     MSHEX
        SUBA.L  #1,A6   ; have to put A6 back at start of ascii
MSASCII MOVE.B  (A6),(A1)+  ; put that char in (A1) and increment A1
        CMPI.B  #0,(A6)+    ; check if end and increment A6 to match A1
        BEQ     MSDONE  ; end of string
        BRA     MSASCII ; repeat
MSHEX   BSR     MEM2HEX ; hex number stored in D1
        CMPI.L  #$FF,D1 ; see size of number
        BLE     MSBYTE
        CMPI.L  #$FFFF,D1
        BLE     MSWORD
MSLONG  ADDA.L  #4,A1   ; move A1 to end of long word
        MOVE.B  D1,-(A1)    ; have to copy 4 bytes
        ROR.L   #8,D1       ; first one was copied, so look at next byte
        MOVE.B  D1,-(A1)    ; copy second byte
        ROR.L   #8,D1
        SUBA.L  #2,A1   ; done to counteract the next action
MSWORD  ADDA.L  #2,A1   ; move A1 to end of word
        MOVE.B  D1,-(A1)    ; will copy 2 bytes
        ROR.L   #8,D1   ; look at second one
        SUBA.L  #1,A1   ; to counteract the fact that MSBYTE doesn't predecrement
MSBYTE  MOVE.B  D1,(A1) ; copy one byte
        BRA     MSDONE
MSINV   BSR     INVALID
MSDONE  MOVEM.L (A7)+,D1/A1
        RTS

* BF -- fills block of memory with word pattern
BF      MOVEM.L D0-D3/D7/A1-A3,-(A7)
        MOVE.B  (A6)+,D1    ; first '$'
        CMPI.B  #$24,D1 ; is it '$'?
        BNE     BFINV ; wrong command usage
        BSR     MEM2HEX ; D1 has 1st address in hex
        MOVEA.L D1,A2   ;store in A2
        MOVE.B  (A6)+,D1    ; space in between addresses
        CMPI.B  #$20,D1 ; is it ' '?
        BNE     BFINV
        MOVE.B  (A6)+,D1    ; second '$'
        CMPI.B  #$24,D1
        BNE     BFINV   
        BSR     MEM2HEX ; D1 has 2nd address in hex
        MOVEA.L D1,A3   ; both addresses have been read now
        CLR.L   D2      ; pattern will go in here
        MOVE.B  (A6)+,D1    ; space before the pattern
        CMPI.B  #$00,D1 ; no pattern given, use default
        BEQ     BFSTART
        CMPI.B  #$20,D1 ; is it ' '?
        BNE     BFINV
        MOVE.L  #3,D3   ; counter for remaining 3 digits (if there)
BFPATT  MOVE.B  (A6)+,D7    ; first byte of pattern
        TST.B   D7
        BEQ     BFSTART ; only one digit was given, use first one padded with a zero
        ASL.L   #4,D2   ; place first digit on the left part of the byte
        BSR     ASCII2NUM
        ADD.B   D7,D2   ; goes into the right part of the byte
        DBF     D3,BFPATT   ; debrease D3 and keep looping until all digits read
BFSTART MOVE.W  (A3),D3 ; TEST: if address2 not even, address error is raised
BFLOOP  CMPA.L  A2,A3
        BLE     BFDONE  ; done when A2 reaches A3
        MOVE.W  D2,(A2)+    ; write the pattern in memory. Address error raised if address1 not even
        BRA     BFLOOP
BFINV   BSR     INVALID
BFDONE  MOVEM.L (A7)+,D0-D3/D7/A1-A3
        RTS
        
* BMOV -- copies block of memory somewhere else
BMOV    MOVEM.L D1/A2-A4,-(A7)
        MOVE.B  (A6)+,D1    ; first '$'
        CMPI.B  #$24,D1 ; is it '$'?
        BNE     BMINV ; wrong command usage
        BSR     MEM2HEX ; D1 has 1st address in hex
        MOVEA.L D1,A2   ;store in A2
        MOVE.B  (A6)+,D1    ; space in between addresses
        CMPI.B  #$20,D1 ; is it ' '?
        BNE     BMINV
        MOVE.B  (A6)+,D1    ; second '$'
        CMPI.B  #$24,D1
        BNE     BMINV   
        BSR     MEM2HEX ; D1 has 2nd address in hex
        MOVE.L  D1,A3   ; store in A3
        MOVE.B  (A6)+,D1    ; space in between addresses
        CMPI.B  #$20,D1 ; is it ' '?
        BNE     BMINV
        MOVE.B  (A6)+,D1    ; third '$'
        CMPI.B  #$24,D1
        BNE     BMINV   
        BSR     MEM2HEX ; D1 has 3rd address in hex
        MOVE.L  D1,A4       ; store in A4
BMLOOP  CMPA.L  A2,A3
        BLE     BMDONE  ; done when A2 reaches A3
        MOVE.B  (A2)+,(A4)+ ; copy
        BRA     BMLOOP
BMINV   BSR     INVALID
BMDONE  MOVEM.L (A7)+,D1/A2-A4
        RTS
        
* BTST -- tests each bit (by setting and unsetting all) in a block of memory
BTERROR DC.B    'MEMORY ERROR FOUND AT LOCATION $00000000'
BTLOC   DC.B    $A,$D ; this and BTREAD point after for HEX2MEM to work
        DC.B    'Value expected: '
BTEXP   DC.B    '00',$A,$D
        DC.B    'Value read: 00'
BTREAD  DC.B    0
BTST    MOVEM.L D0-D1/A1-A3,-(A7)
        MOVE.B  (A6)+,D1    ; first '$'
        CMPI.B  #$24,D1 ; is it '$'?
        BNE     BTINV ; wrong command usage
        BSR     MEM2HEX ; D1 has 1st address in hex
        MOVEA.L D1,A2   ; store in A2
        MOVEA.L A2,A1   ; store copy for BTLOOP2
        MOVE.B  (A6)+,D1    ; space in between addresses
        CMPI.B  #$20,D1 ; is it ' '?
        BNE     BTINV
        MOVE.B  (A6)+,D1    ; second '$'
        CMPI.B  #$24,D1
        BNE     BTINV   
        BSR     MEM2HEX ; D1 has 2nd address in hex
        MOVE.L  D1,A3   ; store in A3
        CLR.L   D1  ; needed to only look at bytes
BTLOOP1 CMPA.L  A2,A3   ; this loop tries bit pattern 1010
        BLE     BTPRELOOP2
        MOVE.B  #$AA,(A2)   ; write
        MOVE.B  (A2)+,D1    ; read
        CMPI.B  #$AA,D1     ; check correct
        BEQ     BTLOOP1     ; move to next byte
        LEA     BTREAD,A1   ; if here, there is a problem in memory!
        BSR     HEX2MEM_NOZ ; load everything to memory, to be able to print error
        LEA     BTEXP,A1
        MOVE.B  #'A',(A1)+
        MOVE.B  #'A',(A1)
        LEA     BTLOC,A1
        SUBA.L  #1,A2
        MOVE.L  A2,D1
        BSR     HEX2MEM
        LEA     BTERROR,A1
        MOVE.B  #13,D0
        TRAP    #15     ; print the error message
        BRA     BTDONE  ; stop execution
BTPRELOOP2  MOVEA.L A1,A2   ; copy was stored a while back to be able to start over
BTLOOP2 CMPA.L  A2,A3   ; this loop tries bit pattern 0101. Works the same as BTLOOP1
        BLE     BTDONE
        MOVE.B  #$55,(A2)   ; write
        MOVE.B  (A2)+,D1    ; read
        CMPI.B  #$55,D1     ; check correct
        BEQ     BTLOOP2     ; move to next byte
        LEA     BTREAD,A1   ; error in memory, act like before
        BSR     HEX2MEM_NOZ
        LEA     BTEXP,A1
        MOVE.B  #'5',(A1)+
        MOVE.B  #'5',(A1)
        LEA     BTLOC,A1
        SUBA.L  #1,A2
        MOVE.L  A2,D1
        BSR     HEX2MEM
        LEA     BTERROR,A1
        MOVE.B  #13,D0
        TRAP    #15
        BRA     BTDONE
BTINV   BSR     INVALID
BTDONE  MOVEM.L (A7)+,D0-D1/A1-A3
        RTS
        
* GO -- executes another program
GO      MOVEM.L D0-D7/A0-A7,-(A7)   ; don't allow the program to change registers
        MOVE.B  (A6)+,D1    ; '$'
        CMPI.B  #$24,D1 ; is it '$'?
        BNE     GOINV   ; wrong command usage
        BSR     MEM2HEX ; D1 has address in hex
        MOVEA.L D1,A0   ;store in A0
        JSR     (A0)    ; execute the program
        BRA     GODONE
GOINV   BSR     INVALID
GODONE  MOVEM.L (A7)+,D0-D7/A0-A7
        RTS
        
* DF -- displays formatted registers
DF      MOVEM.L D0-D2/A0-A1,-(A7)
        LEA     STACK,A0
        ADDA.L  #4,A0   ; placed after A7 in stack
        LEA     DF_MSG_END,A1
DFLOOP  SUBQ.L  #1,A1   ; pass the $A at end of each line
        MOVE.L  #3,D2   ; number of registers per line - 1
DFLINE  MOVE.L  -(A0),D1    ; put register value in D1
        BSR     HEX2MEM     ; will store D1 in -8(A1)
        SUBQ.L  #4,A1   ; skip other characters
        DBF     D2,DFLINE   ; keep looping till line done       
        CMP.L   #DF_MSG,A1
        BGT     DFLOOP
        ADDQ.L  #1,A1   ; put back at the front of the message
        MOVE.B  #13,D0
        TRAP    #15     ; print register value
        MOVEM.L (A7)+,D0-D2/A0-A1
        RTS

* EXIT -- terminates the program
EXIT    LEA     GOODBYE,A1
        MOVE.B  #13,D0
        TRAP    #15     ; print goodbye message
        ADDA.L  #4,A7   ; move past the PC stored in the stack
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
        BSR     HEX2MEM_NOZ ; that number is written as hex in memory
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
        
* Takes 8 digits from D1 in hex and puts them into -8(A1) in ascii:
HEX2MEM MOVEM.L D0/D2/D7,-(A7)    ; store in stack
        CLR.L   D0   ; counter
H2MNEXT MOVE.L  D1,D7
        MOVE.L D0,D2
H2MRIGHT    SUBQ.W  #1,D2
        BLT     H2MDONE
        LSR.L   #4,D7   ; that upper byte to lowest by -> only one left
        BRA     H2MRIGHT
H2MDONE BSR     NUM2ASCII   ; convert to ascii in D7
        MOVE.B  D7,-(A1)
        ADDQ.W  #1,D0
        CMPI.W  #8,D0
        BLT     H2MNEXT
        MOVEM.L (A7)+,D0/D2/D7
        RTS
        
* Takes X digits from D1 in hex and puts them into -X(A1) in ascii (no trailing zeros):
HEX2MEM_NOZ MOVEM.L D0/D2/D7,-(A7)    ; store in stack
        CLR.L   D0   ; counter
H2MZNEXT MOVE.L  D1,D7
        MOVE.L D0,D2
H2MZRIGHT    SUBQ.W  #1,D2
        BLT     H2MZDONE
        LSR.L   #4,D7   ; that upper byte to lowest by -> only one left
        BRA     H2MZRIGHT
H2MZDONE TST.L   D7
        BEQ     H2MZEND      ; if number done
        BSR     NUM2ASCII   ; convert to ascii in D7
        MOVE.B  D7,-(A1)
        ADDQ.W  #1,D0
        CMPI.W  #8,D0
        BLT     H2MZNEXT
H2MZEND  MOVEM.L (A7)+,D0/D2/D7
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
ADDRERR MOVEM.L D0/A1,-(A7)
        MOVEM.L D1/A0,-(A7) ; specific for this interrupt
        LEA     ADDRERR_MSG,A1
        MOVE.B  #13,D0
        TRAP    #15
        BRA     INTERR_REG  ; print the special registers
BERR    MOVEM.L D0/A1,-(A7)
        MOVEM.L D1/A0,-(A7) ; specific for this interrupt
        LEA     BERR_MSG,A1
        MOVE.B  #13,D0
        TRAP    #15
        BRA     INTERR_REG  ; print the special registers
ILLINS  MOVEM.L D0/A1,-(A7)
        LEA     ILLINS_MSG,A1
        BRA     INTERR 
PRIVERR MOVEM.L D0/A1,-(A7)
        LEA     PRIVERR_MSG,A1
        BRA     INTERR 
DIV0    MOVEM.L D0/A1,-(A7)
        LEA     DIV0_MSG,A1
        BRA     INTERR 
CHKERR  MOVEM.L D0/A1,-(A7)
        LEA     CHKERR_MSG,A1
        BRA     INTERR 
LINEA   MOVEM.L D0/A1,-(A7)
        LEA     LINEA_MSG,A1
        BRA     INTERR 
LINEF   MOVEM.L D0/A1,-(A7)
        LEA     LINEF_MSG,A1
        BRA     INTERR
INTERR_REG  ; only BERR and ADDRERR do this
        MOVEA.L A7,A0
        ADDA.L  #24,A0  ; A0 is pointing right below SSW, BA and IR
        MOVEA.L #STACK,A1
        SUBA.L  #60,A1  ; write message in the input space of the stack (currently unused)
        MOVE.B  #0,-(A1)    ; null terminator
        CLR.L   D1
        MOVE.W  -(A0),D1    ; SSW in D1
        BSR     HEX2MEM
        ADDQ.L  #4,A1       ; only want SSW to be a word
        MOVE.B  #' ',-(A1)
        MOVE.L  -(A0),D1    ; BA in D1
        BSR     HEX2MEM
        MOVE.B  #' ',-(A1)
        CLR.L   D1
        MOVE.W  -(A0),D1    ; IR in D1
        BSR     HEX2MEM
        ADDQ.L  #4,A1       ; only want IR to be a word
        MOVEM.L (A7)+,D1/A0 ; restore these specific registers
INTERR  MOVE.B  #13,D0
        TRAP    #15 ; print corresponding message for that interrupt
        BSR     DF  ; print registers
        MOVEM.L (A7)+,D0/A1 ; do here to be able to modify values of A7
        LEA     STACK,A7    ; next 3 instructions put A7 at beginning of input space in stack
        SUBA.L  #60,A7  ; 15 registers that occupy 4 bytes each (2*4 = 8 bits)
        SUBA.L  #MAX_IN_LEN,A7  ; the input space
        BRA     PROMPT
        
*** PROGRAM FOR TESTING GO ***    
    ORG $4000
        MOVEA.L #$4020,A1
        MOVE.L  #$48492100,(A1)
        MOVE.B  #13,D0
        TRAP    #15     ; print secret message
        RTS

END
    END     START        ; last line of source
    



*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
