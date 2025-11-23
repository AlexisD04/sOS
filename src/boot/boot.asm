[org 0x7C00]
bits 16

;
; FAT12 header
;
jmp short start
nop

bdb_oem:                    db 'MSWIN4.1'
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0x0E0
bdb_total_sectors:          dw 2880
bdb_media_descriptor_type:  db 0x0F0
bdb_sectors_per_fat:        dw 9
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; extended boot record
ebr_drive_number:           db 0
                            db 0
ebr_signature:              db 0x29
ebr_volume_id:              db 0x12, 0x34, 0x56, 0x78
ebr_volume_label:           db 'NANOBYTE OS'
ebr_system_id:              db 'FAT12'

start:
    jmp main

main:
  ; setup data segment
  mov ax,0
  mov ds,ax
  mov es,ax

  ; setup stack
  mov ss,ax
  mov sp,0x7C00

  ; read something from floppy disk
  ; BIOS should set DL to drive number
  mov [ebr_drive_number], dl

  mov ax, 1                            ; LBA = 1, second sector from disk
  mov cl, 1                            ; 1 sector to read
  mov bx, 0x7E00                       ; data should be after the bootloader
  
  call disk_read

  ; print message
  mov si, msg
  call puts

  mov si, msg_halt
  call puts

  cli                                  ; deactivate interrupts
  hlt


; Error handler
;

floppy_error:
  mov si, msg_read_failed
  call puts
  jmp wait_key_and_reboot

wait_key_and_reboot:
  mov ah, 0
  int 0x16                             ; wait for keypress
  jmp 0x0FFFF:0                        ; jump to beginning of BIOS, should reboot


;
; Prints a string to the screen
; Params:
;   - ds:si points to string
;
puts:
  ; save registers we will modify
  push si
  push ax
  push bx

.loop:
  lodsb                                ; load next caracter into al
  or al,al                             ; check if next caracter is null?
  jz .done                             ; jump if zero flag risen

  mov ah, 0x0e
  mov bh, 0x00
  int 0x10
  jmp .loop

.done:
  pop bx
  pop ax
  pop si
  ret

;
; Disk routines
;

;
; Converts an LBA address to a CHS address
; Parameters:
;   - ax: LBA address
; Returns:
;   - cx [bits 0-5]: sector number
;   - cx [bits 6-15]: cylinder
;   - dh: head
;

lba_to_chs:

  push ax
  push dx

  xor dx, dx                          ; dx = 0
  div word [bdb_sectors_per_track]    ; ax = LBA / SectorsPerTrack
                                      ; dx = LBA % SectorsPerTrack
  
  inc dx                              ; dx = {LBA % SectorsPerTrack} + 1 = sector
  mov cx, dx;                         ; cx = sector

  xor dx, dx                          ; dx = 0
  div word [bdb_heads]                ; ax = (LBA / SectorsPerTrack) / Heads = cylinder
                                      ; dx = (LBA / SectorsPerTrack) % Heads = head

  mov dh, dl                          ; dh = head
  mov ch, al                          ; ch = cylinder (lower 8 bits)
  shl ah, 6
  or cl, ah                           ; put upper 2 bits of cylinder in CL

  pop ax
  mov dl, al                          ; restore DL
  pop ax
  ret

;
; Reads sectors from a disk
; Parameters:
;   - ax: LBA address
;   - cl: number of sectors to read (up to 128)
;   - dl: drive number
;   - es:bx: memory address where to store read data
;
disk_read:

  push ax                             ; save registers we will modify
  push bx
  push cx
  push dx
  push di

  push cx                             ; temporarily save CL (number of sectors to read)
  call lba_to_chs                     ; compute CHS
  
  
  pop ax                              ; AL = number of sectors to read
  
  mov ah, 0x02
  mov di, 3                           ; retry count

.retry:
  pusha                               ; save all registers, we don't know what bios modifies
  stc                                 ; set carry flag, some BIOS'es don't set it
  int 0x13                            ; carry flag cleared = success
  jnc .done                           ; jump if carry not set

  ; read failed
  popa
  call disk_reset

  dec di
  test di, di
  jnz .retry

.fail:
  ; after attempts are exhausted
  jmp floppy_error

.done:
  popa

  pop di
  pop dx
  pop cx
  pop bx
  pop ax                              ; restore registers modified

  ret

;
; Resets disk controller
; Parameters:
;   dl: drive number
;
disk_reset:
  pusha
  mov ah, 0
  stc
  int 0x13
  jc  floppy_error
  popa
  ret

msg:                db 'Welcome on sOS!',13,10,0
msg_read_failed:    db 'Read from disk failed.',13,10,0
msg_halt:           db 'HALT',13,10,0

times 510-($-$$) db 0
dw 0xAA55