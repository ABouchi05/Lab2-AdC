# Juego RV32E sin shifts, mul ni div. Constantes editables.
.equ WAIT_CYCLES, 75000000
.equ TENTH_CYCLES, 2500000
.equ HOLD_CYCLES, 25000000
.equ RELEASE_CYCLES, 500000
.equ ROUNDS, 10
_start:
    lui x2, 0x80000
    addi x3, x0, 0          # respuestas correctas
    addi x4, x0, 0          # suma de decimas
    addi x5, x0, 37         # estado aleatorio
round:
    addi x6, x0, 15
    sw x6, 4(x2)           # cuatro LEDs; timestamp atomico
    lw x7, 16(x2)
    li x8, WAIT_CYCLES
wait_three:
    lw x9, 12(x2)
    sub x9, x9, x7
    bltu x9, x8, wait_three
    jal x1, release         # no aceptar boton sostenido/anticipado
    lw x9, 12(x2)
    andi x9, x9, 2047      # mezcla bits 0..10 de la semilla temporal
    addi x6, x0, 31
seed_fold:
    bltu x9, x6, seed_ready
    sub x9, x9, x6
    jal x0, seed_fold
seed_ready:
    xor x5, x5, x9
    addi x5, x5, 73
    andi x6, x5, 3
    addi x9, x0, 0
    addi x7, x0, 1
choose:
    beq x9, x6, chosen
    add x7, x7, x7
    addi x9, x9, 1
    jal x0, choose
chosen:
    sw x7, 4(x2)           # LED y comienzo de medicion en el mismo flanco
wait_press:
    lw x9, 24(x2)
    andi x6, x9, 16
    beq x6, x0, wait_press
    andi x6, x9, 15
    bne x6, x7, error       # pulsaciones multiples tambien son error
    lw x9, 20(x2)
    addi x10, x0, 0
    li x8, TENTH_CYCLES
convert:
    bltu x9, x8, converted
    sub x9, x9, x8
    addi x10, x10, 1
    jal x0, convert
converted:
    add x4, x4, x10         # promedio de tiempos cuantizados; sin saturar suma
    addi x3, x3, 1
    jal x1, display
    addi x6, x0, 0
    sw x6, 4(x2)
    li x8, HOLD_CYCLES
    jal x1, pause
    jal x1, release
    addi x6, x0, ROUNDS
    bltu x3, x6, round
    addi x10, x0, 0
average:
    bltu x4, x6, final
    sub x4, x4, x6
    addi x10, x10, 1
    jal x0, average
final:
    jal x1, display
    # Promedio queda visible. Pulsar y soltar cualquier boton reinicia partida.
restart_press:
    lw x6, 8(x2)
    beq x6, x0, restart_press
    jal x1, release
    jal x0, _start
error:
    addi x6, x0, 238        # EE
    sw x6, 0(x2)
    addi x6, x0, 0
    sw x6, 4(x2)
    li x8, HOLD_CYCLES
    jal x1, pause
    jal x1, release
    jal x0, round          # conserva x3 y x4
# Espera x8 ciclos; usa x6,x9,x12 y conserva enlace x1.
pause:
    lw x12, 12(x2)
pause_loop:
    lw x9, 12(x2)
    sub x9, x9, x12
    bltu x9, x8, pause_loop
    jalr x0, 0(x1)
# Botones deben permanecer sueltos 20 ms. Filtra rebotes entre rondas.
release:
    li x8, RELEASE_CYCLES
release_reset:
    lw x12, 12(x2)
release_loop:
    lw x6, 8(x2)
    bne x6, x0, release_reset
    lw x9, 12(x2)
    sub x9, x9, x12
    bltu x9, x8, release_loop
    jalr x0, 0(x1)
# x10 = decimas; display decimal 00..99, saturacion visual en 99.
display:
    addi x11, x10, 0
    addi x13, x0, 99
    bltu x11, x13, decimal
    addi x11, x0, 99
decimal:
    addi x13, x0, 0
    addi x14, x0, 10
decimal_loop:
    bltu x11, x14, decimal_done
    addi x11, x11, -10
    addi x13, x13, 16
    jal x0, decimal_loop
decimal_done:
    add x11, x11, x13
    sw x11, 0(x2)
    jalr x0, 0(x1)
