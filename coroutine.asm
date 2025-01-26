.equ STACK_SIZE,          0x1000
.equ COROUTINE_CAPACITY,  0x0A
.equ SYS_EXIT,            0x3C
.equ SYS_WRITE,           0x01
.equ STDOUT,              0x01
.equ STDERR,              0x02
.equ OVERFLOW,            0x45

.section .text
  .globl _start
  _start:
    call coroutine_init

    leaq generator, %rdi
    call create_coroutine

    leaq generator, %rdi
    call create_coroutine

  _loop:
    call coroutine_yield
    call _loop

    movq $SYS_WRITE, %rax
    movq $STDERR, %rdi
    movq $execution_success, %rsi
    movq $execution_success_len, %rdx
    syscall

    movq $SYS_EXIT, %rax
    movq $OVERFLOW, %rdi
    syscall
    

  .globl coroutine_init
  coroutine_init:
    movq coroutine_index(%rip), %rbx
    cmpq $COROUTINE_CAPACITY, %rbx
    jge overflow

    addq $0x01, coroutine_index(%rip)

    popq %rax                            # return address is in %rax now
    movq %rsp, coroutine_rsp(,%rbx,0x08)
    movq %rbp, coroutine_rbp(,%rbx,0x08)
    movq %rax, coroutine_rip(,%rbx,0x08)

    jmpq *%rax

  .globl create_coroutine
  create_coroutine:
    movq coroutine_index(%rip), %rbx
    cmpq $COROUTINE_CAPACITY, %rbx
    jge overflow

    addq $0x01, coroutine_index(%rip)

    movq stacks_top(%rip), %rax         # %rax contains the rsp of new coroutine 
    subq $STACK_SIZE, stacks_top(%rip)  # Reduce stack size
    subq $0x08, %rax
    movq $coroutine_return, (%rax)
    
    movq %rax,  coroutine_rsp(,%rbx,0x08)
    movq $0x00, coroutine_rbp(,%rbx,0x08)
    movq %rdi,  coroutine_rip(,%rbx,0x08)
   
    ret
    # .byte 0xCC [int3 Interrupt] (Program will terminate with SIGTRAP signal.)

  .globl coroutine_yield
  coroutine_yield:
    movq coroutine_current(%rip), %rbx

    popq %rax                                # return address is in rax now
    movq %rsp, coroutine_rsp(,%rbx,0x08)
    movq %rbp, coroutine_rbp(,%rbx,0x08)
    movq %rax, coroutine_rip(,%rbx,0x08)

    incq %rbx
    xorq %rcx, %rcx
    cmpq coroutine_index(%rip), %rbx
    cmovge %rcx, %rbx
    movq %rbx, coroutine_current(%rip)
  
    movq coroutine_rsp(,%rbx,0x08), %rsp
    movq coroutine_rbp(,%rbx,0x08), %rbp
    jmpq *coroutine_rip(,%rbx,0x08)

  .globl _coroutine_return
  coroutine_return:
    movq $SYS_WRITE, %rax
    movq $STDOUT, %rdi
    movq $execution_finish, %rsi
    movq $execution_finish_len, %rdx
    syscall

    movq $SYS_EXIT, %rax
    xorq %rdi, %rdi
    syscall
  
  .globl overflow
  overflow:
    movq $SYS_WRITE, %rax
    movq $STDERR, %rdi
    movq $overflow_error, %rsi
    movq $overflow_error_len, %rdx
    syscall

    movq $SYS_EXIT, %rax
    movq $OVERFLOW, %rdi
    syscall

  generator:
    # Allocate memory on stack for our variables
    push %rbp                 # Push the base address to stack
    movq %rsp, %rbp         
    sub  $0x10, %rsp          # Reduce the stack size

    # Initialize counter to 0.
    movq $0x0, -0x08(%rbp)

  .loop:
    cmpq $0x0A, -0x08(%rbp)     # Check if the condition is valid (counter should be less than 10)
    jge .end                    # If validation fails, jump to .end to break the loop

    movq -0x08(%rbp), %rdi      # Argument to print_number
    call print_number
    call coroutine_yield
    
    incq -0x08(%rbp)            # increament the counter
    jmp .loop                   # repeat

  .end:
    addq $0x10, %rsp            # Increase the stack size
    pop %rbp
    ret

  print_number:
    push  %rbx                   # only save what we need
    sub   $0x20, %rsp            # reduced stack size
    mov   %edi, %eax             # number to print in eax
    lea   0x1F(%rsp), %rbx       # point to end of buffer
    movb  $0x0A, (%rbx)          # store newline at end
  
  .continue:
    xor  %edx, %edx             # clear for division
    mov  $0x0A, %ecx            # divisor
    div  %ecx                   # divide by 10
    add  $0x30, %dl             # convert remainder to ASCII
    dec  %rbx                   # move buffer pointer
    mov  %dl, (%rbx)            # store digit
    test %eax, %eax             # check if more digits
    jnz  .continue              # continue if not zero

    # Calculate length and write
    lea 0x1F(%rsp), %rdx            # point to buffer end
    sub %rbx, %rdx                  # calculate length
    mov %rbx, %rsi                  # buffer address
    mov $STDOUT, %edi               # stdout
    mov $SYS_WRITE, %rax            # write syscall
    syscall

    # Write newline to stdout
    movq $SYS_WRITE, %rax         # syscall number for sys_write (1)
    movq $STDOUT, %rdi            # file descriptor (1 -> stdout)
    lea newline(%rip), %rsi       # pointer to newline
    movq $0x01, %rdx              # length of data to write (1 byte)
    syscall

    add $0x20, %rsp               # restore stack
    pop %rbx                      # restore saved register
    ret

.section .data
  newline:
    .byte 0x0A

  .globl coroutine_index
  coroutine_index:
    .quad 0x00
  coroutine_current:
    .quad 0x00
  stacks_top:
    .quad stack_pool + (STACK_SIZE * COROUTINE_CAPACITY) 

  overflow_error:
    .asciz "Reached maximum capacity for coroutines (ERR:OVERFLOW).\n"
  overflow_error_len = . - overflow_error
  
  execution_success:
    .asciz "Executed Successfully.\n"
  execution_success_len = . - execution_success

  execution_finish:
    .asciz "Execution Finished.\n"
  execution_finish_len = . - execution_finish

.section .bss
  .lcomm coroutine_rsp, 0x08 * COROUTINE_CAPACITY
  .lcomm coroutine_rbp, 0x08 * COROUTINE_CAPACITY
  .lcomm coroutine_rip, 0x08 * COROUTINE_CAPACITY

  .lcomm stack_pool,    STACK_SIZE * COROUTINE_CAPACITY
