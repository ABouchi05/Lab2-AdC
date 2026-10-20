import shutil, subprocess, sys, os
from pathlib import Path
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tools'))
from assembler import assemble
build=root/'build'; build.mkdir(exist_ok=True)
source=(root/'sw/game.s').read_text()
for old,new in [('75000000','30000'),('2500000','1000'),('25000000','10000'),('500000','2000')]: source=source.replace(old,new)
words,symbols=assemble(source)
(build/'sim.hex').write_text(''.join(f'{w:08x}\n' for w in words)+'00000013\n'*(512-len(words)))
model=Path(shutil.which('yosys')).parent.parent/'share/yosys/ice40/cells_sim.v'
os.environ['PATH']=str(model.parents[3]/'lib')+os.pathsep+os.environ['PATH']
rtl=list((root/'rtl').glob('*.v'))+list((root/'rtl/espino_core').glob('*.v'))
subprocess.run(['iverilog','-g2012','-DNO_ICE40_DEFAULT_ASSIGNMENTS','-s','tb','-o',str(build/'sim.vvp'),str(model),*[str(f) for f in rtl],str(root/'tests/tb_game.v')],cwd=root,check=True)
subprocess.run(['vvp',str(build/'sim.vvp')],cwd=root,check=True)
