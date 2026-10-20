import unittest
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from assembler import assemble
class AssemblerTests(unittest.TestCase):
    def words(self,s): return assemble(s)[0]
    def test_known_vectors(self):
        self.assertEqual(self.words("addi x1,x0,1\nsub x3,x1,x2\nlw x1,12(x2)\nsw x1,4(x2)\nlui x2,0x80000"),[0x00100093,0x402081b3,0x00c12083,0x00112223,0x80000137])
    def test_labels(self):
        self.assertEqual(self.words("loop: addi x1,x1,-1\nbne x1,x0,loop\njal x0,loop"),[0xfff08093,0xfe009ee3,0xff9ff06f])
    def test_li_layout(self):
        self.assertEqual(assemble("li x1,2048\nnext: jal x0,next")[1]["next"],8)
        self.assertEqual(self.words("li x1,2048"),[0x000010b7,0x80008093])
    def test_rejections(self):
        for source in ["addi x16,x0,0","addi x1,x0,2048","beq x1,x0,missing","a: add x0,x0,x0\na: add x0,x0,x0","slli x1,x1,2","jal x0,2","sw x1,0(x0),x2","li x1,0x100000000"]:
            with self.subTest(source=source),self.assertRaises(ValueError): assemble(source)
if __name__=="__main__": unittest.main()
