"""Assembler propio RV32E. No invoca programas externos. Dos pasadas."""
import argparse
import re
from pathlib import Path

R = {"add": (0,0), "sub": (0,32), "xor": (4,0), "or": (6,0), "and": (7,0), "slt": (2,0), "sltu": (3,0)}
I = {"addi":0,"xori":4,"ori":6,"andi":7,"slti":2,"sltiu":3}
B = {"beq":0,"bne":1,"blt":4,"bge":5,"bltu":6,"bgeu":7}

def reg(s):
    if not re.fullmatch(r"x(?:[0-9]|1[0-5])", s):
        raise ValueError("registro RV32E invalido: " + s)
    return int(s[1:])

def number(s, symbols):
    if s in symbols: return symbols[s]
    try: return int(s, 0)
    except ValueError: raise ValueError("numero o etiqueta desconocida: " + s)

def bounded(v, bits):
    if not -(1 << (bits-1)) <= v < (1 << (bits-1)):
        raise ValueError(f"inmediato {v} fuera de rango de {bits} bits")
    return v & ((1 << bits)-1)

def operands(line):
    return [x for x in re.split(r"[\s,()]+", line.strip()) if x]

def encode(line, pc, symbols):
    a = operands(line); op = a.pop(0)
    def count(n):
        if len(a) != n: raise ValueError("cantidad de operandos incorrecta: " + op)
    if op in R:
        count(3); rd,rs,rt=map(reg,a); f3,f7=R[op]
        return [f7<<25 | rt<<20 | rs<<15 | f3<<12 | rd<<7 | 0x33]
    if op in I:
        count(3); rd,rs=map(reg,a[:2]); v=bounded(number(a[2],symbols),12)
        return [v<<20 | rs<<15 | I[op]<<12 | rd<<7 | 0x13]
    if op in ("lw","jalr","sw"):
        count(3); r=reg(a[0]); v=bounded(number(a[1],symbols),12); rs=reg(a[2])
        if op == "sw": return [(v>>5)<<25 | r<<20 | rs<<15 | 2<<12 | (v&31)<<7 | 0x23]
        return [v<<20 | rs<<15 | (2 if op=="lw" else 0)<<12 | r<<7 | (3 if op=="lw" else 0x67)]
    if op == "lui":
        count(2); rd=reg(a[0]); v=number(a[1],symbols)
        if not 0 <= v <= 0xfffff: raise ValueError("lui requiere inmediato unsigned de 20 bits")
        return [v<<12 | rd<<7 | 0x37]
    if op in B or op == "jal":
        count(2 if op=="jal" else 3)
        target=a[-1]; offset=number(target,symbols)-(pc if target in symbols else 0)
        if offset % 4: raise ValueError("destino debe estar alineado a 4 bytes")
        v=bounded(offset,21 if op=="jal" else 13)
        if op=="jal":
            return [(v>>20)<<31 | ((v>>1)&1023)<<21 | ((v>>11)&1)<<20 | ((v>>12)&255)<<12 | reg(a[0])<<7 | 0x6f]
        return [(v>>12)<<31 | ((v>>5)&63)<<25 | reg(a[1])<<20 | reg(a[0])<<15 | B[op]<<12 | ((v>>1)&15)<<8 | ((v>>11)&1)<<7 | 0x63]
    if op == "li":
        count(2); rd=reg(a[0]); v=number(a[1],symbols)
        if not -(1<<31) <= v <= 0xffffffff: raise ValueError("li fuera de 32 bits")
        lo=((v+2048)&4095)-2048; hi=((v-lo)>>12)&0xfffff
        return [hi<<12 | rd<<7 | 0x37, (lo&4095)<<20 | rd<<15 | rd<<7 | 0x13]
    raise ValueError("instruccion no soportada: " + op)

def assemble(source):
    symbols={}; rows=[]; pc=0
    for lineno,raw in enumerate(source.splitlines(),1):
        line=raw.split("#",1)[0].strip()
        if not line: continue
        try:
            if line.startswith(".equ "):
                _,name,value=operands(line)
                if name in symbols: raise ValueError("simbolo duplicado: "+name)
                symbols[name]=number(value,symbols); continue
            if ":" in line:
                label,line=line.split(":",1); label=label.strip(); line=line.strip()
                if not re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*",label): raise ValueError("etiqueta invalida")
                if label in symbols: raise ValueError("simbolo duplicado: "+label)
                symbols[label]=pc
            if not line: continue
            if line in (".section .text",".text") or line.startswith(".global "): continue
            rows.append((lineno,pc,line)); pc+=8 if operands(line)[0]=="li" else 4
        except ValueError as e: raise ValueError(f"linea {lineno}: {e}") from e
    result=[]
    for lineno,pc,line in rows:
        try: result.extend(encode(line,pc,symbols))
        except ValueError as e: raise ValueError(f"linea {lineno}: {e}") from e
    if len(result)>512: raise ValueError("programa supera RAM de 512 palabras")
    return result,symbols

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("source",type=Path); ap.add_argument("output",type=Path)
    args=ap.parse_args()
    try:
        words,symbols=assemble(args.source.read_text(encoding="utf-8-sig"))
        args.output.write_text("".join(f"{w:08x}\n" for w in words))
        args.output.with_suffix(".symbols.json").write_text(__import__("json").dumps(symbols,indent=2))
        print(f"OK: {len(words)} palabras, {len(words)*4} bytes -> {args.output}")
    except ValueError as e: ap.exit(1,str(e)+"\n")
if __name__=="__main__": main()
