;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                 ;;
;; Copyright (C) KolibriOS team 2010-2015. All rights reserved.    ;;
;; Distributed under terms of the GNU General Public License       ;;
;;                                                                 ;;
;;  telnet.asm - Telnet client for KolibriOS                       ;;
;;                                                                 ;;
;;  Written by hidnplayr@kolibrios.org                             ;;
;;                                                                 ;;
;;          GNU GENERAL PUBLIC LICENSE                             ;;
;;             Version 2, June 1991                                ;;
;;                                                                 ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

format binary as ""

BUFFERSIZE      = 4096

use32
; standard header
        db      'MENUET01'      ; signature
        dd      1               ; header version
        dd      start           ; entry point
        dd      i_end           ; initialized size
        dd      mem+4096        ; required memory
        dd      mem+4096        ; stack pointer
        dd      hostname        ; parameters
        dd      0               ; path

include '../../macros.inc'
purge mov,add,sub
include '../../proc32.inc'
include '../../dll.inc'
include '../../network.inc'

; entry point
start:
; load libraries
        stdcall dll.Load, @IMPORT
        test    eax, eax
        jnz     exit
; initialize console
        invoke  con_start, 1
        invoke  con_init, 80, 25, 80, 25, title

; Check for parameters
        cmp     byte[hostname], 0
        jne     resolve

main:
        invoke  con_cls
; Welcome user
        invoke  con_write_asciiz, str1

prompt:
; write prompt
        invoke  con_write_asciiz, str2
; read string (wait for input)
        mov     esi, hostname
        invoke  con_gets, esi, 256
; check for exit
        test    eax, eax
        jz      done
        cmp     byte[esi], 10
        jz      done

resolve:
        mov     [sockaddr1.port], 23 shl 8      ; Port is in network byte order

; delete terminating newline from URL and parse port, if any.
        mov     esi, hostname
  @@:
        lodsb
        cmp     al, ':'
        je      .do_port
        cmp     al, 0x20
        ja      @r
        mov     byte[esi-1], 0
        jmp     .done

  .do_port:
        xor     eax, eax
        xor     ebx, ebx
        mov     byte[esi-1], 0
  .portloop:
        lodsb
        cmp     al, ' '
        jbe     .port_done
        sub     al, '0'
        jb      hostname_error
        cmp     al, 9
        ja      hostname_error
        lea     ebx, [ebx*4+ebx]
        shl     ebx, 1
        add     ebx, eax
        jmp     .portloop

  .port_done:
        xchg    bl, bh
        mov     [sockaddr1.port], bx

  .done:

; resolve name
        push    esp     ; reserve stack place
        invoke  getaddrinfo, hostname, 0, 0, esp
        pop     esi
; test for error
        test    eax, eax
        jnz     dns_error

        invoke  con_cls
        invoke  con_write_asciiz, str3
        invoke  con_write_asciiz, hostname

; write results
        invoke  con_write_asciiz, str8

; convert IP address to decimal notation
        mov     eax, [esi+addrinfo.ai_addr]
        mov     eax, [eax+sockaddr_in.sin_addr]
        mov     [sockaddr1.ip], eax
        invoke  inet_ntoa, eax
; write result
        invoke  con_write_asciiz, eax
; free allocated memory
        invoke  freeaddrinfo, esi

        invoke  con_write_asciiz, str9

        mcall   socket, AF_INET4, SOCK_STREAM, 0
        cmp     eax, -1
        jz      socket_err
        mov     [socketnum], eax

        mcall   connect, [socketnum], sockaddr1, 18
        test    eax, eax
        jnz     socket_err

        mcall   40, EVM_STACK
        invoke  con_cls

        mcall   18, 7
        push    eax
        mcall   51, 1, thread, mem - 2048
        pop     ecx
        mcall   18, 3

mainloop:
        invoke  con_get_flags
        test    eax, 0x200                      ; con window closed?
        jnz     exit

        mcall   recv, [socketnum], buffer_ptr, BUFFERSIZE, 0
        cmp     eax, -1
        je      closed

        mov     esi, buffer_ptr
        lea     edi, [esi+eax]
        mov     byte[edi], 0
  .scan_cmd:
        cmp     byte[esi], 0xff         ; Interpret As Command
        jne     .no_cmd
; TODO: parse options
; for now, we will reply with 'WONT' to everything
        mov     byte[esi+1], 252        ; WONT
        add     esi, 3                  ; a command is always 3 bytes
        jmp     .scan_cmd
  .no_cmd:

        cmp     esi, buffer_ptr
        je      .print

        push    esi edi
        sub     esi, buffer_ptr
        mcall   send, [socketnum], buffer_ptr, , 0
        pop     edi esi

  .print:
        cmp     esi, edi
        jae     mainloop

        invoke  con_write_asciiz, esi

  .loop:
        lodsb
        test    al, al
        jz      .print
        jmp     .loop


socket_err:
        invoke  con_write_asciiz, str6
        jmp     prompt

dns_error:
        invoke  con_write_asciiz, str5
        jmp     prompt

hostname_error:
        invoke  con_write_asciiz, str11
        jmp     prompt

closed:
        invoke  con_write_asciiz, str12
        jmp     prompt

done:
        invoke  con_exit, 1
exit:

        mcall   close, [socketnum]
        mcall   -1



thread:
        mcall   40, 0
  .loop:
        invoke  con_getch2
        mov     [send_data], ax
        xor     esi, esi
        inc     esi
        test    al, al
        jnz     @f
        inc     esi
  @@:
        mcall   send, [socketnum], send_data

        invoke  con_get_flags
        test    eax, 0x200                      ; con window closed?
        jz      .loop
        mcall   -1

; data
title   db      'Telnet',0
str1    db      'Telnet for KolibriOS',10,10,\
                'Please enter URL of telnet server (host:port)',10,10,\
                'fun stuff:',10,\
                'telehack.com            - arpanet simulator',10,\
                'towel.blinkenlights.nl  - ASCII Star Wars',10,\
                'nyancat.dakko.us        - Nyan cat',10,10,0
str2    db      '> ',0
str3    db      'Connecting to ',0
str4    db      10,0
str8    db      ' (',0
str9    db      ')',10,0

str5    db      'Name resolution failed.',10,10,0
str6    db      'Could not open socket.',10,10,0
str11   db      'Invalid hostname.',10,10,0
str12   db      10,'Remote host closed the connection.',10,10,0

sockaddr1:
        dw AF_INET4
.port   dw 0
.ip     dd 0
        rb 10

align 4
@IMPORT:

library network, 'network.obj', console, 'console.obj'
import  network,        \
        getaddrinfo,    'getaddrinfo',  \
        freeaddrinfo,   'freeaddrinfo', \
        inet_ntoa,      'inet_ntoa'
import  console,        \
        con_start,      'START',        \
        con_init,       'con_init',     \
        con_write_asciiz,       'con_write_asciiz',     \
        con_exit,       'con_exit',     \
        con_gets,       'con_gets',\
        con_cls,        'con_cls',\
        con_getch2,     'con_getch2',\
        con_set_cursor_pos, 'con_set_cursor_pos',\
        con_write_string, 'con_write_string',\
        con_get_flags,  'con_get_flags'


i_end:

socketnum       dd ?
buffer_ptr      rb BUFFERSIZE+1
send_data       dw ?

hostname        rb 1024

mem:
