# RED spike: where does 8-bit premultiplied STORAGE lose vs straight storage + float premult inside the kernel?
import numpy as np
rng=np.random.default_rng(1)
N=256
y,x=np.mgrid[0:N,0:N]
# soft hair-like alpha: gaussian falloff, many low-alpha pixels; colour varies smoothly (skin/hair tones)
a=np.clip(255*np.exp(-(((x-128)**2+(y-128)**2)/(2*40.0**2))*1.0)-0,0,255)
a=np.where(a<2,0,a).round().astype(np.float64)
col=np.stack([200+30*np.sin(x/9.0),120+40*np.cos(y/7.0),80+20*np.sin((x+y)/11.0)],-1).clip(0,255).round()
def box(img,r):
    k=2*r+1; p=np.pad(img,[(r,r),(r,r)]+[(0,0)]*(img.ndim-2),mode='edge'); c=p.cumsum(0).cumsum(1)
    c=np.pad(c,[(1,0),(1,0)]+[(0,0)]*(img.ndim-2))
    return (c[k:,k:]-c[:-k,k:]-c[k:,:-k]+c[:-k,:-k])/(k*k)
r=6
af=a/255.
# reference: float premultiplied blur, float unpremultiply
P=col*af[...,None]; Pb=box(P,r); Ab=box(af,r)
ref=np.where(Ab[...,None]>1e-6,Pb/np.maximum(Ab[...,None],1e-6),0)
# H (straight storage, float inside kernel, round once at end)
H=ref.round()
# B (8-bit premult storage at load, 8-bit blur result, 8-bit unpremult on save)
P8=(col*a[...,None]/255).round(); A8=a
Pb8=box(P8,r).round(); Ab8=box(A8,r).round()
B=np.where(Ab8[...,None]>0,(Pb8*255/np.maximum(Ab8[...,None],1)).round(),0).clip(0,255)
# A-naive straight blur
S=box(col,r).round()
mask=(Ab8>0)
for lo,hi in [(1,10),(11,50),(51,254)]:
    m=(Ab8>=lo)&(Ab8<=hi)
    print(f"out alpha {lo}-{hi} n={m.sum():6d}  mean|err| vs float ref: B(8bit premult storage)={np.abs(B-ref)[m].mean():.2f} max={np.abs(B-ref)[m].max():.0f} | H(straight+float kernel)={np.abs(H-ref)[m].mean():.2f} | A-naive straight blur={np.abs(S-ref)[m].mean():.2f}")
# flattened over mid-grey backdrop (what a JPEG thumbnail shows): composite error
bg=np.full(col.shape,90.0)
def comp_straight(c,al): return c*(al/255)[...,None]+bg*(1-al/255)[...,None]
Rr=comp_straight(ref,Ab*255)
Bc=Pb8+bg*(1-Ab8/255)[...,None]
Hc=comp_straight(H,Ab*255)
print("flattened over grey: max abs level err  B=%.1f  H=%.1f"%(np.abs(Bc-Rr).max(),np.abs(Hc-Rr).max()))
print("flattened over grey: mean abs level err B=%.3f  H=%.3f"%(np.abs(Bc-Rr).mean(),np.abs(Hc-Rr).mean()))
