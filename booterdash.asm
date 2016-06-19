.8086
    IS_FLOPPY = 0
    BOULDER = 0807h
    DIRT = 06B1h
    WALL = 08DBh
    ROCKFORD = 0E02h
    DIAMOND = 0B04h
    BLAST = 0C0Fh
    EXIT = 0F7Fh
    AIR = 0720h
    DIAMOND_COUNT = 30
    BOULDER_COUNT = 250
    AIR_COUNT = 150
    K_UP = 72
    K_LEFT = 75
    K_RIGHT = 77
    K_DOWN = 80
    K_S = 31
    VIDEO_MODE = 0003h;0001h
    SCREEN_WIDTH = 80
    SCREEN_HEIGHT = 25
    SCREEN_OFFSET_MASK = 0FFEh
    SEED = 0FEEDh
BOOT_SEG segment public

    org 7b00h
timer byte ?
rand word ?
diamonds byte ?

    org 7c00h
    
    IF IS_FLOPPY
    jmp BootCode ; 2 byte jump
    nop
    byte "MSDOS5.0" ; OEM identifier
    word 512 ;sector size in bytes
    byte 1 ; cluster size in sectors
    word 1 ; reserved sectors
    byte 2 ; number of FAT copies
    word 224 ; number of directory entries
    word 2880 ; total sectors
    byte 0F0h ; media descriptor
    word 9 ; sectors per FAT
    word 18 ; sectors per track
    word 2 ; heads/sides
    dword 0 ; hidden sectors
    dword 0 ; larger total sectors count
    byte 00h ; drive number (drive A)
    byte 00h ; reserved/Windows NT flags
    byte 29h ; signature, must be 28h or 29h
    dword 0 ; serial number
    byte "KRD BOOTER " ; volume label
    byte "FAT12   " ; system identifier
BootCode:
    ENDIF
    
    ;long jump into code so that segment:offset is always consistent
    byte 0eah
    word offset begin,0000h ;offset,segment
;entry point
on_tic proc
    inc timer
    iret
on_tic endp

wait_for_tic proc
    mov timer,0
retry:
    cmp timer,0
    je retry
    ret
wait_for_tic endp

randomize proc
    mov ax,rand
    shr al,1
    rol ah,1
    jnc noxor
    xor al,0B4h
noxor:
    xor ah,al
    mov rand,ax
    ret
randomize endp

place_objects proc
place:
    push ax
    call randomize
    pop ax
    mov bx,rand
    and bx,SCREEN_OFFSET_MASK
    cmp byte ptr [bx], byte ptr DIRT
    jne place
    mov [bx],ax
    loop place
    ret
place_objects endp


begin proc
    cli
    ;init stack
    mov ax,7000h
    mov ss,ax
    mov ax,0FFFEh
    mov sp,ax
    
    ;set vectors
    mov bx,1Ch*4
    mov word ptr cs:[bx], offset on_tic
    inc bx
    inc bx
    mov word ptr cs:[bx], cs

    mov ax, 0B800h
    mov es,ax
    mov ds,ax
    sti
    
    mov rand,SEED
    
round:
    mov bp,(SCREEN_WIDTH+1)*2 ; bp = position of Rockford
    mov diamonds,DIAMOND_COUNT
    
    mov ax,VIDEO_MODE
    int 10h
    
    mov ax,WALL
    xor di,di
    mov cx,SCREEN_WIDTH
    rep stosw
    
    mov di, (SCREEN_WIDTH*(SCREEN_HEIGHT-1))*2
    mov cx,SCREEN_WIDTH
    rep stosw

    mov bx,(SCREEN_WIDTH)*2
    mov es:[bx],ax
    add bx,(SCREEN_WIDTH-1)*2
    mov es:[bx],ax

    mov ax,DIRT
    mov di,(SCREEN_WIDTH+1)*2
    mov cx,SCREEN_WIDTH-2
    rep stosw
    
    mov si,(SCREEN_WIDTH)*2
    mov di,(SCREEN_WIDTH*2)*2
    mov cx,(SCREEN_HEIGHT-3)*SCREEN_WIDTH
    rep movsw
    
    mov bx,(SCREEN_WIDTH*(SCREEN_HEIGHT-2)+SCREEN_WIDTH-2)*2
    mov word ptr [bx],EXIT
    
    push rand
    
    mov cl,DIAMOND_COUNT
    mov ax,DIAMOND
    call place_objects

    mov cx,BOULDER_COUNT
    mov ax,BOULDER
    call place_objects

    mov cx,AIR_COUNT
    mov ax,AIR
    call place_objects
    
    mov bx,bp
    mov word ptr [bx], ROCKFORD


gameloop:
    xor si,si
    mov ah,1
    int 16h
    jz no_move
    mov ah,0
    int 16h
    cmp ah,K_UP
    jne not_up
    mov si,-SCREEN_WIDTH*2
not_up:
    cmp ah,K_LEFT
    jne not_left
    mov si,-2
not_left:
    cmp ah,K_RIGHT
    jne not_right
    mov si,2
not_right:
    cmp ah,K_DOWN
    jne not_down
    mov si,SCREEN_WIDTH*2
not_down:
    cmp ah,K_S
    jne not_s
    jmp round
not_s:
    mov bx,bp
    cmp byte ptr [bx][si], byte ptr WALL
    je no_move
    cmp byte ptr [bx][si], byte ptr BOULDER
    je no_move
    cmp diamonds,0
    je move
    cmp byte ptr [bx][si], byte ptr EXIT
    je no_move
move:
    cmp byte ptr [bx][si], byte ptr DIAMOND
    jne no_collect
    dec diamonds
    jnz no_collect
    mov byte ptr ds:(SCREEN_WIDTH*(SCREEN_HEIGHT-1)*2 - 3), 8Fh
no_collect:
    cmp byte ptr [bx][si], byte ptr EXIT
    je round
    mov byte ptr [bx], byte ptr AIR
    mov word ptr [bx][si], ROCKFORD
    add bp,si
no_move:

    mov bx,(SCREEN_WIDTH)*2 - 2
    mov cx,SCREEN_WIDTH*(SCREEN_HEIGHT-3) + 1
update:
    inc bx
    inc bx
    dec cx
    jz done
    cmp byte ptr [bx],byte ptr BOULDER
    je has_gravity
    cmp byte ptr [bx],byte ptr DIAMOND
    je has_gravity
    jmp update
has_gravity:
    mov si,SCREEN_WIDTH*2
    cmp byte ptr [bx][si], byte ptr AIR
    je fall
    cmp byte ptr [bx][si], byte ptr DIRT
    je update
    cmp byte ptr [bx][si], byte ptr ROCKFORD
    je update
    dec si
    dec si
    cmp byte ptr [bx][si], byte ptr AIR
    je fall_sideways
    add si,4
    cmp byte ptr [bx][si], byte ptr AIR
    je fall_sideways
    jmp update
fall_sideways:
    cmp byte ptr [bx-SCREEN_WIDTH*2][si], byte ptr AIR
    jne update
fall:
    mov ax,[bx]
    mov word ptr [bx][si], ax
    mov byte ptr [bx],byte ptr AIR
    call wait_for_tic
    cmp byte ptr [bx+SCREEN_WIDTH*2][si], byte ptr ROCKFORD
    je death
    jmp update
death:
    mov word ptr ds:[bp], BLAST
    call wait_for_tic
    call wait_for_tic
    pop rand
    jmp round
done:
    jmp gameloop
IF IS_FLOPPY
;boot sector signature
    org 7dfeh
    dw 55aah
ENDIF    


begin endp

BOOT_SEG ends

END