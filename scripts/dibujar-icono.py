"""Dibuja el icono de Glucy: una gota con la curva medida en línea continua y la estimada en
punteada, la misma regla de la interfaz. Uso: python3 scripts/dibujar-icono.py Glucy/Assets.xcassets/AppIcon.appiconset
"""
import math, sys
from PIL import Image, ImageDraw
S=1024; k=4; N=S*k
def gota(fondo, gota_color, linea_color, ruta):
    im=Image.new("RGB",(N,N),fondo); d=ImageDraw.Draw(im)
    cx, cy, r = N/2, N*0.60, N*0.245
    top = N*0.17
    # Cuerpo: un círculo y un triángulo tangente.
    d.ellipse([cx-r,cy-r,cx+r,cy+r], fill=gota_color)
    ang=math.asin(r/(cy-top))
    tx=r*math.cos(ang); ty=r*math.sin(ang)
    d.polygon([(cx,top),(cx-tx,cy-ty),(cx+tx,cy-ty)], fill=gota_color)
    # Línea continua (lo medido) que sigue en punteada (lo estimado).
    w=int(N*0.034)
    pts=[(cx-r*0.72,cy+r*0.18),(cx-r*0.30,cy-r*0.12),(cx,cy+r*0.10)]
    d.line(pts,fill=linea_color,width=w,joint="curve")
    for p in pts[:1]+pts[-1:]: d.ellipse([p[0]-w/2,p[1]-w/2,p[0]+w/2,p[1]+w/2],fill=linea_color)
    a=(cx,cy+r*0.10); b=(cx+r*0.72,cy-r*0.30)
    L=math.dist(a,b); n=3
    for i in range(n):
        t0=i/n+0.22; t1=t0+0.12
        p0=(a[0]+(b[0]-a[0])*t0,a[1]+(b[1]-a[1])*t0); p1=(a[0]+(b[0]-a[0])*t1,a[1]+(b[1]-a[1])*t1)
        d.line([p0,p1],fill=linea_color,width=w)
        for p in (p0,p1): d.ellipse([p[0]-w/2,p[1]-w/2,p[0]+w/2,p[1]+w/2],fill=linea_color)
    im.resize((S,S),Image.LANCZOS).save(ruta)
dest=sys.argv[1]
gota((0x1A,0x56,0xDB),(255,255,255),(0x1A,0x56,0xDB),dest+"/icono-claro.png")
gota((0x0B,0x0F,0x17),(0x7E,0xA6,0xFF),(0x0B,0x0F,0x17),dest+"/icono-oscuro.png")
# Tintado: blanco sobre negro; iOS lo tiñe con el color que elija la persona.
gota((0,0,0),(255,255,255),(0,0,0),dest+"/icono-tintado.png")
