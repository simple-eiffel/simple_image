# Adjudicator spike: a solid-colour+alpha layer (halo, shadow, text shadow) blurred as a MASK and
# filled with its colour through cairo-style mask compositing, vs premultiplied RGBA blur, vs naive straight blur.
import numpy as np
N=128; y,x=np.mgrid[0:N,0:N]
a=np.zeros((N,N)); a[(x-64)**2+(y-64)**2<30**2]=255.0          # hard-edged disk (text glyph/panel stand-in)
c=np.array([30.,200.,90.])                                      # solid layer colour
def box(img,r):
    k=2*r+1; p=np.pad(img,[(r,r),(r,r)]+[(0,0)]*(img.ndim-2),mode='edge'); s=p.cumsum(0).cumsum(1)
    s=np.pad(s,[(1,0),(1,0)]+[(0,0)]*(img.ndim-2)); return (s[k:,k:]-s[:-k,k:]-s[k:,:-k]+s[:-k,:-k])/(k*k)
r=7; bg=np.full((N,N,3),140.)
# (1) premultiplied RGBA blur in float, composite over bg  (reference)
P=box(c*(a/255)[...,None],r); Ab=box(a,r)/255; ref=P+bg*(1-Ab[...,None])
# (2) mask path, 8-bit: blur alpha, round to 8 bits (IMG_MASK), fill colour through mask over bg
m8=box(a,r).round(); mk=c*(m8/255)[...,None]+bg*(1-m8/255)[...,None]
# (3) naive straight RGBA blur with transparent BLACK under alpha 0, composite over bg
rgb=np.where(a[...,None]>0,c,0.); S=box(rgb,r); nv=S*Ab[...,None]+bg*(1-Ab[...,None])
e2=np.abs(mk-ref); e3=np.abs(nv-ref)
print("float identity: max |blur(c*a) - c*blur(a)| =", np.abs(P-c*Ab[...,None]).max())
print("mask path (8-bit mask) vs premult reference, flattened: max %.2f mean %.3f levels"%(e2.max(),e2.mean()))
print("naive straight blur vs reference, flattened:            max %.2f mean %.3f levels"%(e3.max(),e3.mean()))
