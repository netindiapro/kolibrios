;
;   �ਬ�� �ணࠬ�� ��� MenuetOS
;   ����稢��� ��� ����⮩ ������ ;)
;
;   �������஢��� FASM'��
;
;   ��. ⠪��:
;     template.asm  -  �ਬ�� ���⥩襩 �ணࠬ�� (����!)
;     rb.asm        -  ���⥪�⭮� ���� ࠡ�祣� �⮫�
;     example2.asm  -  �ਬ�� ���� � �������⥫��� ����
;     example3.asm  -  �ਬ�� ����, ॠ����������� ��-��㣮��
;---------------------------------------------------------------------

  use32              ; ������� 32-���� ०�� ��ᥬ����
  org    0x0         ; ������ � ���

  db     'MENUET01'  ; 8-����� �����䨪��� MenuetOS
  dd     0x01        ; ����� ��������� (�ᥣ�� 1)
  dd     START       ; ���� ��ࢮ� �������
  dd     I_END       ; ࠧ��� �ணࠬ��
  dd     0x1000      ; ������⢮ �����
  dd     0x1000      ; ���� ���設� �����
  dd     0x0         ; ���� ���� ��� ��ࠬ��஢ (�� �ᯮ������)
  dd     0x0         ; ��१�ࢨ஢���

include 'lang.inc'
include 'macros.inc' ; ������ �������� ����� ��ᥬ����騪��!

;---------------------------------------------------------------------
;---  ������ ���������  ----------------------------------------------
;---------------------------------------------------------------------

START:

red:                    ; ����ᮢ��� ����

    call draw_window    ; ��뢠�� ��楤��� ���ᮢ�� ����

;---------------------------------------------------------------------
;---  ���� ��������� �������  ----------------------------------------
;---------------------------------------------------------------------

still:
    mcall 10            ; �㭪�� 10 - ����� ᮡ���

    cmp  eax,1          ; ����ᮢ��� ���� ?
    je   red            ; �᫨ �� - �� ���� red
    cmp  eax,2          ; ����� ������ ?
    je   key            ; �᫨ �� - �� key
    cmp  eax,3          ; ����� ������ ?
    je   button         ; �᫨ �� - �� button

    jmp  still          ; �᫨ ��㣮� ᮡ�⨥ - � ��砫� 横��


;---------------------------------------------------------------------


  key:                  ; ����� ������ �� ���������
    mcall 2             ; �㭪�� 2 - ����� ��� ᨬ���� (� ah)

    mov  [Music+1], ah  ; ������� ��� ᨬ���� ��� ��� ����

    ; �㭪�� 55-55: ��⥬�� ������� ("PlayNote")
    ;   esi - ���� �������

    ;   mov  eax,55
    ;   mov  ebx,eax
    ;   mov  esi,Music
    ;   int  0x40

    ; ��� ���⪮:
    mcall 55, eax, , , Music

    jmp  still          ; �������� � ��砫� 横��

;---------------------------------------------------------------------

  button:
    mcall 17            ; 17 - ������� �����䨪��� ����⮩ ������

    cmp   ah, 1         ; �᫨ �� ����� ������ � ����஬ 1,
    jne   still         ;  ��������

  .exit:
    mcall -1            ; ���� ����� �ணࠬ��



;---------------------------------------------------------------------
;---  ����������� � ��������� ����  ----------------------------------
;---------------------------------------------------------------------

draw_window:

    mcall 12, 1                    ; �㭪�� 12: ᮮ���� �� �� ���ᮢ�� ����
                                   ; 1 - ��稭��� �ᮢ���

    ; �����: ᭠砫� ������ ��ਠ�� (���������஢����)
    ;        ��⥬ ���⪨� ������ � �ᯮ�짮������ ����ᮢ


                                   ; ������� ����
;   mov  eax,0                     ; �㭪�� 0 : ��।����� � ���ᮢ��� ����
;   mov  ebx,200*65536+200         ; [x ����] *65536 + [x ࠧ���]
;   mov  ecx,200*65536+100         ; [y ����] *65536 + [y ࠧ���]
;   mov  edx,0x02aabbcc            ; 梥� ࠡ�祩 ������  RRGGBB,8->color gl
;   mov  esi,0x805080d0            ; 梥� ������ ��������� RRGGBB,8->color gl
;   mov  edi,0x005080d0            ; 梥� ࠬ��            RRGGBB
;   int  0x40

    mcall 0, <200,200>, <200,50>, 0x02AABBCC, 0x805080D0, 0x005080D0

                                   ; ��������� ����
;   mov  eax,4                     ; �㭪�� 4 : ������� � ���� ⥪��
;   mov  ebx,8*65536+8             ; [x] *65536 + [y]
;   mov  ecx,0x10ddeeff            ; ���� 1 � 梥� ( 0xF0RRGGBB )
;   mov  edx,header                ; ���� ��ப�
;   mov  esi,header.size           ; � �� �����
;   int  0x40

    mcall 4, <8,8>, 0x10DDEEFF, header, header.size

;   mov  eax,4
;   mov  ebx,8 shl 16 + 30
;   mov  ecx,0
;   mov  edx,message
;   mov  esi,message.size
;   int  0x40

    mcall 4, <8, 30>, 0, message, message.size

                                   ; ������ �������� ����
;   mov  eax,8                     ; �㭪�� 8 : ��।����� � ���ᮢ��� ������
;   mov  ebx,(200-19)*65536+12     ; [x ����] *65536 + [x ࠧ���]
;   mov  ecx,5*65536+12            ; [y ����] *65536 + [y ࠧ���]
;   mov  edx,1                     ; �����䨪��� ������ - 1
;   mov  esi,0x6688dd              ; 梥� ������ RRGGBB
;   int  0x40

    mcall 8, <200-19, 12>, <5, 12>, 1, 0x6688DD

    mcall 12, 2                    ; �㭪�� 12: ᮮ���� �� �� ���ᮢ�� ����
                                   ; 2, �����稫� �ᮢ���

    ret                            ; ��室�� �� ��楤���


;---------------------------------------------------------------------
;---  ������ ���������  ----------------------------------------------
;---------------------------------------------------------------------

; ��� ⠪�� ��� ���⪠� "�������".
; ��ன ���� ��������� ����⨥� �������

Music:
  db  0x90, 0x30, 0


;---------------------------------------------------------------------

; ����䥩� �ணࠬ�� ���������
;  �� ����� ������ �� � MACROS.INC (lang fix ��)

lsz message,\
  ru,'������ ���� �������...',\
  en,'Press any key...',\
  fr,'Pressez une touche...'

lsz header,\
  ru,'������ ���������',\
  en,'EXAMPLE APPLICATION',\
  fr,"L'exemplaire programme"

;---------------------------------------------------------------------

I_END:                             ; ��⪠ ���� �ணࠬ��
