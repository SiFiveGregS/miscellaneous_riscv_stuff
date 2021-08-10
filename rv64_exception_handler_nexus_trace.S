.text

.global rv64_handler_for_exercising_nexus_trace

.align 4
rv64_handler_for_exercising_nexus_trace:

    # This handler is intended as a way to capture interrupt/exception entry/return events
    # in RISC-V Nexus trace.  It's only been tested on RV64, so far, but now it might also operate correctly
    # on RV32.
	
    # If a timer interrupt happens, this handler disables further timer interrupts and returns.
    # Otherwise, this handler silently advances past the faulting instruction and returns.

    # Definitely not the kind of behavior that is suitable for a trap handler in a conventional
    # system.

    # Save a0 in mscratch (clobber old mscratch since we'll be using a0 for something else
    csrw mscratch, a0

    # If this was a timer interrupt, then disable further timer interrupts and return.
    # (Note: This instruction sequence has inefficiencies as a tradeoff for the fact that we are
    # restricting our register usage to a0 only)

    csrr a0, mcause
    bge a0, zero, not_timer_interrupt  // sign bit isn't 1, not an interrupt

    // mask off upper bit
    slli a0, a0, 1
    srli a0, a0, 1
    // check for residual value of 7 (indicating machine mode timer interrupt)
    xori a0, a0, 0x7
    bne a0, zero, not_timer_interrupt

    # Must be timer interrupt, lets clear MIE.MTIE
    csrr a0, mie
    andi a0, a0, -129 // all bits set except bit 7 (portable way of expressing that for both RV32/RV64)
    csrw mie, a0

    # restore a0 from mscratch
    csrr a0, mscratch
    # return without messing with MEPC
    mret

not_timer_interrupt:

    # Let's assume the reason is some sort of memory fault.  We could check mcause, but for now,
    #  we won't bother.  This purpose of this handler is just to help us collect examples of exception/interrupt
    #  event trace.

    # Silently advance MEPC past the faulting instruction and return to the instruction stream
    # that included the faulting instruction.
    # THIS MAKES THE CALLING CODE RESPONSIBLE FOR NEVER PURPOSELY
    # CAUSING AN EXCEPTION AS A RESULT OF A CONTROL FLOW INSTRUCTION!!!

    # To avoid save/restore beyond just a0 (via mscratch) we're using only a0 as GPR,
    # so for that reason the code here has some inefficiencies
    # that wouldn't be present if we were using additional registers

    csrr a0, mepc
    # Figure out if MEPC is pointing at a 16-bit or 32-bit instruction.
    # 32-bit instructions have '1' as least significant 2 bits of first halfword parcel
    lh a0, 0(a0)
    andi a0, a0, 0x3
    slti a0, a0, 0x3  // t0 = t0 < 3
    bne a0, zero, inst_16
    # If we get here, it is a 32-bit instruction.  Reload MEPC, advance it by 4
    csrr a0, mepc
    addi a0, a0, 4
    j write_mepc_and_exit_trap
inst_16:
    # If we get here, it is a 16-bit instruction     Reload MEPC, advance it by 2
    csrr a0, mepc
    addi a0, a0, 2
write_mepc_and_exit_trap:
    csrw mepc, a0
    # restore a0 from mscratch
    csrr a0, mscratch
    mret

