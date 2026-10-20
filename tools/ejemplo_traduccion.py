from assembler import assemble

# Ejemplo de una instruccion del juego
instruccion = 'lw x9, 12(x2)'
palabras, _ = assemble(instruccion)
codigo = palabras[0]

print('Instruccion:', instruccion)
print('Lee una palabra desde x2 + 12 y la guarda en x9.')
print()
print('Campos del formato I:')
print('Inmediato = 12')
print('rs1 = 2')
print('funct3 = 2')
print('rd = 9')
print('opcode = 3')
print()
print('Binario:', format(codigo, '032b'))
print('Hexadecimal:', format(codigo, '08x'))
