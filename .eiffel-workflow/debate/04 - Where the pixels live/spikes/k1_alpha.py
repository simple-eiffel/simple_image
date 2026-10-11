import numpy as np
# (a) 8-bit premultiply (round c*a/255, cairo MUL_UN8) then unpremultiply (round c*255/a, clamp)
c=np.arange(256,dtype=np.int64)[:,None]; a=np.arange(1,255,dtype=np.int64)[None,:]
t=c*a+128; p=(t+(t>>8))>>8
u=np.minimum(255,(p*255+a//2)//a)
err=np.abs(u-c)
print("a in 1..254, c in 0..255: max err",err.max(),"mean err",round(err.mean(),4))
for lo,hi in [(1,3),(1,10),(11,50),(51,127),(128,254)]:
    e=err[:,lo-1:hi]; print(f" alpha {lo}-{hi}: max {e.max()} mean {e.mean():.3f}  distinct output levels at a={lo}: {len(set(u[:,lo-1]))}")
print(" alpha=1: output colour levels", sorted(set(u[:,0].tolist())))
# (b) blur
N=64; yy,xx=np.mgrid[:N,:N]
disk=((yy-32)**2+(xx-32)**2)<=14**2
img=np.zeros((N,N,4),dtype=np.float64); img[disk]=[255,0,0,255]
def box(ch,r=4):
    k=2*r+1; pad=np.pad(ch,r,mode='edge'); out=np.zeros_like(ch)
    for dy in range(k):
        for dx in range(k): out+=pad[dy:dy+N,dx:dx+N]
    return out/(k*k)
def rnd(x): return np.clip(np.floor(x+0.5),0,255)
s=np.stack([rnd(box(img[...,i])) for i in range(4)],-1)           # (i) straight, independent
pm=img.copy(); pm[...,:3]=img[...,:3]*img[...,3:4]/255
pb=np.stack([box(pm[...,i]) for i in range(4)],-1)
al=rnd(pb[...,3]); col=np.where(pb[...,3:4]>0,pb[...,:3]/np.maximum(pb[...,3:4],1e-9)*255,0)
p2=np.dstack([rnd(col),al])                                        # (ii) premult, unpremult
m=(s[...,3]>=10)&(s[...,3]<=200)
print("edge pixels alpha 10-200:",int(m.sum()))
print("(i) straight blur  : R mean %.1f min %.1f  (true colour R=255)"%(s[m][:,0].mean(),s[m][:,0].min()))
m2=(p2[...,3]>=10)&(p2[...,3]<=200)
print("(ii) premult blur  : R mean %.1f min %.1f  n=%d"%(p2[m2][:,0].mean(),p2[m2][:,0].min(),int(m2.sum())))
print("example row y=32, x=14..22 (i): ",s[32,14:23].astype(int).tolist())
print("example row y=32, x=14..22 (ii):",p2[32,14:23].astype(int).tolist())
# composite both over white background: error vs ideal
