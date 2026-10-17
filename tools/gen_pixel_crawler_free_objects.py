import os, re, random, string
from PIL import Image
import numpy as np
ROOT=os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','..','..'))+'/'
PACK='assets/pixel_crawler/packs/free_pack_2.11/Pixel Crawler - Free Pack/Environment/Props/Static/'
OUT=ROOT+'modules/quiz_rpg/scenes/objects/pixel_crawler/'
B34='abcdefghijklmnopqrstuvwxy012345678'
def uid_of(png):
    t=open(ROOT+png+'.import').read()
    return re.search(r'uid="(uid://[^"]+)"',t).group(1)
def nid(n=8):
    return ''.join(random.choice(string.ascii_lowercase+string.digits) for _ in range(n))
random.seed(7)
used=set()
def uniq():
    while True:
        v=random.randint(10**9,2**31-1)
        if v not in used: used.add(v); return v
def tight(a,rect):
    x,y,w,h=rect
    sub=a[y:y+h,x:x+w]
    yy,xx=np.where(sub)
    return (x+int(xx.min()),y+int(yy.min()),int(xx.max()-xx.min()+1),int(yy.max()-yy.min()+1))
def base_width(a,rect,rows=3):
    x,y,w,h=rect
    sub=a[y+h-rows:y+h,x:x+w]
    xs=np.where(sub.any(axis=0))[0]
    return int(xs.max()-xs.min()+1), int((xs.max()+xs.min()+1)/2)  # width, centre offset in px from x
def write(group,name,png,rect,coll,meta=None):
    """coll: (halfw, top_y, bottom_y, cx) w px względem origin lub None; origin = środek dołu - 2 px"""
    x,y,w,h=rect
    u=uid_of(png); pth='res://'+png
    cx = w/2.0
    offx=-int(round(cx)); offy=-(h-2)
    title=''.join(p.capitalize() for p in name.split('_'))
    s='[gd_scene format=3]\n\n'
    s+=f'[ext_resource type="Texture2D" uid="{u}" path="{pth}" id="1_{nid(5)}"]\n\n'
    rid=re.search(r'id="(1_\w+)"',s).group(1)
    s+=f'[sub_resource type="AtlasTexture" id="AtlasTexture_{nid(5)}"]\natlas = ExtResource("{rid}")\nregion = Rect2({x}, {y}, {w}, {h})\nfilter_clip = true\n\n'
    sid=re.search(r'id="(AtlasTexture_\w+)"',s).group(1)
    s+=f'[node name="{title}" type="StaticBody2D" unique_id={uniq()}]\ncollision_layer = 32\ncollision_mask = 0\nmetadata/object_group = "{meta or group}"\n\n'
    s+=f'[node name="Sprite2D" type="Sprite2D" parent="." unique_id={uniq()}]\ntexture = SubResource("{sid}")\ncentered = false\noffset = Vector2({offx}, {offy})\n'
    if coll:
        hw,t,b,cxo=coll
        s+=f'\n[node name="CollisionPolygon2D" type="CollisionPolygon2D" parent="." unique_id={uniq()}]\n'
        pts=[(-hw+cxo,t+1),(-hw+cxo+1,t),(hw+cxo-1,t),(hw+cxo,t+1),(hw+cxo,b-1),(hw+cxo-1,b),(-hw+cxo+1,b),(-hw+cxo,b-1)]
        s+='polygon = PackedVector2Array('+', '.join(f'{int(px)}, {int(py)}' for px,py in pts)+')\n'
    d=OUT+group+'/'; os.makedirs(d,exist_ok=True)
    open(d+name+'.tscn','w',newline='\n').write(s)
    print(group,name,rect,'coll' if coll else '-')

def load(png): return np.array(Image.open(ROOT+png).convert('RGBA'))[:,:,3]>0
# --- drzewa: arkusze to siatki wariantów (pory roku, pniaki, sadzonki) ---
from scipy import ndimage
GRID={(1,2):(64,64,4,2),(1,3):(48,96,4,2),(1,4):(80,128,4,2),(1,5):(112,160,4,2),
      (2,2):(64,48,2,2),(2,3):(48,80,3,2),(2,4):(64,112,3,2),(2,5):(96,160,3,2),
      (3,2):(64,80,2,2),(3,3):(64,144,3,2),(3,4):(96,208,3,2),(3,5):(128,256,3,2)}
CAP={2:4,3:5,4:7,5:10}
GRP={2:'trees_small',3:'trees_medium',4:'trees_large',5:'trees_large'}
for (m,sz),(cw,ch,nc,nr) in GRID.items():
    png=PACK+f'Trees/Model_0{m}/Size_0{sz}.png'
    a=load(png)
    H,W=a.shape
    cells={}
    # region siatki: komórki ch x cw, reszta arkusza (pniaki) = ('out',)
    def comps_of(mask,ox,oy):
        lab,k=ndimage.label(mask,structure=np.ones((3,3)))
        res=[]
        for i,sl in enumerate(ndimage.find_objects(lab)):
            n=int((lab[sl]==i+1).sum())
            res.append([ox+sl[1].start,oy+sl[0].start,sl[1].stop-sl[1].start,sl[0].stop-sl[0].start,n])
        return res
    for r_ in range(nr):
        for c_ in range(nc):
            cells[(c_,r_)]=comps_of(a[r_*ch:(r_+1)*ch,c_*cw:(c_+1)*cw],c_*cw,r_*ch)
    rest=a.copy(); rest[:ch*nr,:cw*nc]=False
    cells[('out',)]=comps_of(rest,0,0)
    cells={k:v for k,v in cells.items() if v}
    for key,lst in sorted(cells.items(),key=lambda kv:str(kv[0])):
        lst.sort(key=lambda c:-c[4])
        out_cell= key==('out',)
        main_h=lst[0][3]
        stumps_cell= out_cell or main_h<0.3*ch
        for j,c in enumerate(lst):
            if c[4]<15: continue
            r=(c[0],c[1],c[2],c[3])
            if stumps_cell:
                nm='stump_m%d_s%d_%s'%(m,sz,'o%d'%j if out_cell else 'r%dc%d_%d'%(key[1],key[0],j))
                if c[3]<8: continue
                write('stumps',nm,png,r,(max(3,c[2]//3),-3,2,0),'stumps')
                continue
            if j==0:
                bw,bc=base_width(a,r,3)
                hw=max(3,min(CAP[sz],bw//4+2))
                cxo=int(round(r[0]+bc-(r[0]+r[2]/2.0)))
                write('trees','tree_m%d_s%d_r%dc%d'%(m,sz,key[1],key[0]),png,r,(hw,-4,2,cxo),GRP[sz])
            elif c[3]>=16:
                write('trees','sapling_m%d_s%d_r%dc%d_%d'%(m,sz,key[1],key[0],j),png,r,(3,-3,2,0),'trees_small')
# --- Vegetation ---
V=PACK+'Vegetation.png'; av=load(V)
cols=[(2,'green'),(50,'olive'),(98,'ochre'),(146,'rust')]
bands=[(5,33,'small'),(33,64,'medium'),(64,97,'large')]
for x0,col in cols:
    for y0,y1,sz in bands:
        r=tight(av,(x0-2 if x0>2 else 0,y0,47,y1-y0))
        # przytnij do kolumny: x0-2..x0+45
        r=tight(av,(x0,y0,44,y1-y0)) if True else r
        bw=r[2]
        write('bushes',f'bush_{col}_{sz}',V,r,(max(4,int(bw*0.35)),-5,2,0))
write('trees','dead_tree_a',V,(197,65,34,31),(3,-4,2,0),'trees_small')
write('trees','dead_tree_b',V,(196,98,39,46),(3,-4,2,0),'trees_medium')
write('trees','stump',V,(242,133,12,11),(4,-3,2,0),'trees_small')
# --- skały ---
R=PACK+'Rocks.png'; ar=load(R)
for col,(dy) in {'brown':0,'grey':0,'dark':96}.items(): pass
rocks={'brown':[(2,19,28,43),(35,19,26,27),(65,17,31,14),(48,51,15,10)],
       'grey':[(98,19,28,43),(131,19,26,27),(161,17,31,14),(144,51,15,10)],
       'dark':[(2,115,28,43),(35,115,26,27),(65,113,31,14),(48,147,15,10)]}
for col,lst in rocks.items():
    for nm,rect in zip(['tall','big','pair','small'],lst):
        r=tight(ar,rect)
        c=(max(3,int(r[2]*0.4)),-4,3,0) if nm!='small' else (max(3,int(r[2]*0.35)),-3,2,0)
        write('rocks',f'rock_{col}_{nm}',R,r,c)
for i,(nm,rect) in enumerate(zip(['crystal_tall','crystal_mid','crystal_short'],[(146,279,12,25),(164,284,8,20),(179,285,10,19)])):
    write('crystals',f'{nm}',R,tight(ar,rect),(max(2,rect[2]//3),-3,2,0))
