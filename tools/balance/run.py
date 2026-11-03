from sim import *
from missions import M
for m in M:
    c=run(m,competent); nv=run(m,naive)
    print(f"{m['id']:2} {m['name']:18} COMP {summary(c,m)}")
    print(f"{'':21} NAIV {summary(nv,m)}")
