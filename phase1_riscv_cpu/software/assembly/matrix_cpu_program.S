.section .text
.globl _start

_start:
    # Frozen memory-map bases
    addi x20, x0, 0          # Matrix A base = 0x00000000
    lui  x21, 0x00001        # Matrix B base = 0x00001000
    lui  x22, 0x00002        # Matrix C base = 0x00002000
    lui  x23, 0x00003        # Control base  = 0x00003000

    # Read programmable dimensions
    lw   x10, 0(x23)         # M
    lw   x11, 4(x23)         # K
    lw   x12, 8(x23)         # N

    # Precalculate row strides
    slli x27, x12, 2         # B row stride = N * 4
    slli x29, x11, 2         # A row stride = K * 4

    # Clear overflow and done
    addi x28, x0, 0
    sw   x28, 12(x23)
    sw   x28, 16(x23)

    # Outer-row initialization
    addi x13, x0, 0          # i = 0
    addi x16, x20, 0         # Current A row pointer
    addi x17, x22, 0         # Current C output pointer

row_loop:
    addi x14, x0, 0          # j = 0
    addi x24, x21, 0         # Current B column start

column_loop:
    addi x18, x16, 0         # A element pointer
    addi x19, x24, 0         # B element pointer
    addi x25, x0, 0          # 64-bit accumulator low
    addi x26, x0, 0          # 64-bit accumulator high
    addi x15, x0, 0          # p = 0

dot_product_loop:
    lw   x5, 0(x18)          # A[i][p]
    lw   x6, 0(x19)          # B[p][j]

    # Returns signed 32-bit product in x7
    jal  x1, multiply_signed_16

    # Add signed product into 64-bit accumulator x26:x25
    add  x8, x25, x7
    sltu x9, x8, x25         # Carry from low word
    srai x4, x7, 31          # Product sign extension
    add  x26, x26, x4
    add  x26, x26, x9
    addi x25, x8, 0

    # Move to A[i][p+1] and B[p+1][j]
    addi x18, x18, 4
    add  x19, x19, x27

    addi x15, x15, 1
    blt  x15, x11, dot_product_loop

    # Check whether signed 64-bit accumulator fits signed 32-bit
    addi x30, x0, 0
    beq  x26, x30, accumulator_high_zero

    addi x30, x0, -1
    beq  x26, x30, accumulator_high_minus_one

    # Other positive/negative upper words require saturation
    blt  x26, x0, saturate_negative
    jal  x0, saturate_positive

accumulator_high_zero:
    # High = 0 and low negative means positive overflow
    blt  x25, x0, saturate_positive
    jal  x0, store_matrix_result

accumulator_high_minus_one:
    # High = -1 and low positive means negative overflow
    bge  x25, x0, saturate_negative
    jal  x0, store_matrix_result

saturate_positive:
    # x25 = 0x7FFFFFFF
    lui  x25, 0x80000
    addi x25, x25, -1
    addi x28, x0, 1
    jal  x0, store_matrix_result

saturate_negative:
    # x25 = 0x80000000
    lui  x25, 0x80000
    addi x28, x0, 1

store_matrix_result:
    sw   x25, 0(x17)

    addi x17, x17, 4         # Next C element
    addi x24, x24, 4         # Next B column
    addi x14, x14, 1         # j++

    blt  x14, x12, column_loop

    add  x16, x16, x29       # Next A row
    addi x13, x13, 1         # i++

    blt  x13, x10, row_loop

    # Save final overflow flag and DONE
    sw   x28, 12(x23)

    addi x30, x0, 1
    sw   x30, 16(x23)

    ebreak

# ------------------------------------------------------------
# Signed 16-bit fixed-step multiplication
#
# Inputs:
#   x5 = signed A element
#   x6 = signed B element
#
# Output:
#   x7 = signed 32-bit product
#
# The loop always executes exactly 16 iterations.
# ------------------------------------------------------------
multiply_signed_16:
    xor  x2, x5, x6
    slt  x2, x2, x0         # x2 = result sign

    bge  x5, x0, multiplicand_absolute_ready
    sub  x5, x0, x5

multiplicand_absolute_ready:
    bge  x6, x0, multiplier_absolute_ready
    sub  x6, x0, x6

multiplier_absolute_ready:
    addi x3, x0, 0          # Product
    addi x4, x0, 16         # Fixed iteration count

multiply_loop:
    andi x8, x6, 1
    beq  x8, x0, multiply_skip_add

    add  x3, x3, x5

multiply_skip_add:
    slli x5, x5, 1
    srli x6, x6, 1

    addi x4, x4, -1
    bne  x4, x0, multiply_loop

    beq  x2, x0, multiply_sign_ready
    sub  x3, x0, x3

multiply_sign_ready:
    addi x7, x3, 0
    jalr x0, 0(x1)