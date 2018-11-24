pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
--davbo's platformer engine

test=""

function _init()
 --constants
 --pixel distance in map units
 pixel=0.125
 --collision offset
 coloffset=0.001
 
 jumpframesoffset=5
 
 --jump physics consts
 -- try changing them!
 airgravity,airtvel=0.04,0.45
 wallgravity,walltvel=0.02,0.275
 
 currentgravity=airgravity
 currenttvel=airtvel

 --avatar
 av={
  --movement vars
  x=17,
  xvel=0,
  y=1,
  yvel=0,
  stickframes=0,
  jumpframes=jumpframesoffset,
  jumping=false,
  rise=0,
  
  --movement consts
  xgroundacc=0.025,
  xgrounddecel=0.4,
  xairacc=0.02,
  xairdecel=0.9,
  xmaxvel=0.2,
  
  yjumpforce=0.55,
  ywalljumpforce=0.45,
  
  maxstickframes=8,
  maxjumpframes=10+jumpframesoffset,
  
  --height and width consts
  -- try changing them!
  h=pixel*14,
  w=pixel*10,
  
  --collision
  onground=false,
  onleft=false,
  onright=false,
  r=5*pixel,
  
  --animation
  sprite=0,
  
  --each body part is sepertate
  -- sprite sheet positions
  -- and widths
  -- and ofset from pos to draw
  head={
   xs=16,
   ys=8,
   ws=7,
   hs=8,
   xof=4,
   yof=-1.0007,
   xoff=0,
  },
  
  body={
   xs=24,
   ys=8,
   ws=10,
   hs=9,
   xof=0,
   yof=3,
   xoff=0,
  },
  
  arm={
   xs=36,
   ys=10,
   ws=3,
   hs=4,
   xof=1,
   yof=6.003,
   xoff=6,
  },
  
  --this'll need to be drawn
  -- twice, for each leg...?
  lleg={
   xs=24,
   ys=20,
   ws=3,
   hs=4,
   xof=1,
   yof=10.5,
   xoff=0,
  },
  
  rleg={
   xs=24,
   ys=20,
   ws=3,
   hs=4,
   xof=7,
   yof=10.5,
   xoff=6,
  },
  
  fist={
   x=17,
   xvel=0,
   y=1,
   yvel=0,
   col=3,
   r=2*pixel,
   attached=true,
   escaped=false,
  },
 }
 
 --organise parts into draw order
 av.parts={
  av.lleg,
  av.rleg,
  av.body,
  av.head,
  av.arm,
 }
 
 --create based on x,y,h,w
 updatehitboxes()
end

function _update()
 updateinput()
 updatecollision()
 updateav()
 updatehitboxes()
end

function updateinput()
 -- jump set dy
 if btnp(4) then
  --different jumps
  --collision resets flags
  if av.onground==true then
   av.jumping=true
   av.yvel=-av.yjumpforce
  elseif av.onleft==true then
   av.jumping=true
   av.yvel=-av.ywalljumpforce
   av.xvel=av.xmaxvel
  elseif av.onright==true then
   av.jumping=true
   av.yvel=-av.ywalljumpforce
   av.xvel=-av.xmaxvel
  end
 end
 
 --variable jump hight calcs
 if av.jumping and
    av.jumpframes<av.maxjumpframes then
  av.jumpframes+=1
 end

 if not btn(4) and
    av.jumping then
  local fraction=av.jumpframes/av.maxjumpframes
  av.yvel*=fraction
  av.jumping=false
  av.jumpframes=jumpframesoffset
 end

 --x input reaction
 if av.onground then
  if btn(0) then
   xaccelerate(av,av.xgroundacc,-1)
  elseif btn(1) then
   xaccelerate(av,av.xgroundacc,1)
  else --ground decel
   av.xvel*=av.xgrounddecel
  end
 else --air x movement
  if btn(0) then
   stickorfall(-1)
  elseif btn(1) then
   stickorfall(1)
  else --in air decel
   av.xvel*=av.xairdecel
   av.stickframes=av.maxstickframes
  end
 end
end

function updatecollision()
 --prevent going into corner
 if av.yvel<0 and
   --not av.onground and
   not mapcol(av.left,av.xvel,0,0) and
   not mapcol(av.right,av.xvel,0,0) and
   (mapcol(av.left,av.xvel,av.yvel,0) or
   mapcol(av.right,av.xvel,av.yvel,0)) and
 		mapcol(av.top,av.xvel,av.yvel,0) and
 		not mapcol(av.top,0,av.yvel,0) then
		av.yvel=0
 end
 
 if mapcol(av.bottom,0,av.yvel,0) then
  moveavtoflag(0)
  av.yvel=0
  
  av.onground=true
  av.onleft=false
  av.onright=false
 else
  av.onground=false

  if mapcol(av.top,0,av.yvel,0) then
   av.yvel=0
   moveavtoroof()
  end
 end
 
 if mapcol(av.bottom,0,av.yvel,1) and
   not mapcol(av.left,0,0,1) and
   not mapcol(av.right,0,0,1) then
  moveavtoflag(1)
  av.yvel=0
  
  av.onground=true
  av.onleft=false
  av.onright=false
 end
 
 av.onleft=avsidecol(av.left,moveavtoleft)
 av.onright=avsidecol(av.right,moveavtoright)
end

function updateav()
 if av.xvel>av.xgroundacc or
    av.onleft then
  av.flipped=false
 elseif av.xvel<av.xgroundacc*-1 or
        av.onright then
  av.flipped=true
 end

 --slide down wall slower
 if (av.onleft or
    av.onright) and
    av.yvel>0 then
  currentgravity=wallgravity
  currenttvel=walltvel
 else
  currentgravity=airgravity
  currenttvel=airtvel
 end

 --update dy if falling
 if not av.onground then
  av.yvel+=currentgravity
  
  --prevent variable jump effect
  -- after jump apex
  if av.yvel>0 then
   av.jumping=false
   av.jumpframes=jumpframesoffset
   
		end

  --terminal velocity
  if av.yvel>currenttvel then
   av.yvel=currenttvel
  end
 end
 
 av.x+=av.xvel
 av.y+=av.yvel
 
 if av.xvel*sgn(av.xvel)<0.001 then
  av.xvel=0
 end
 
 --update rise
 -- breathing rise/fall control
 -- for 'animation'
 av.rise+=sin((stat(95)%10)/3)/1000
 
 av.rise*=0.9
 
 updatefist(av.fist)
end

function updatefist(fist)
 if fist.attached then
  fist.x=av.x+(av.w*0.5)
  fist.y=av.y+(av.h*0.7)

  --throw fist
  if btnp(❎) then
   if av.flipped then
    fist.xvel=-1
   else
    fist.xvel=1
   end
   fist.attached=false
  end
  
 else
  --gravitate to centre of shrek  
  movetopoint(fist,
   av.x+(av.w*0.5),
   av.y+(av.h*0.7),1)
 
  if circlecollision(fist,av) and
     fist.escaped==true then
   --re-attach
   fist.attached=true
   fist.escaped=false
   fist.xvel=0
   fist.yvel=0
  end
  
  if not circlecollision(fist,av) and
     fist.escaped==false then
   fist.escaped=true
  end
 end

end

function _draw()
 cls()
 camera(128,0)
 map(0,0,0,0,32,16,0)
 --[[sspr(0,8,
  av.w*8,(av.h*8)+2,
  av.x*8,av.y*8-(2*pixel),
  av.w*8,(av.h*8)+2,av.flipped)
]]
 for p in all(av.parts) do
  if av.flipped then
   sspr(p.xs,p.ys,
   	p.ws,p.hs,
   	(av.x*8)+p.xoff,
   	(av.y*8)+p.yof+av.rise,
   	p.ws,p.hs,
   	av.flipped)
  else
   sspr(p.xs,p.ys,
   	p.ws,p.hs,
   	(av.x*8)+p.xof,
   	(av.y*8)+p.yof+av.rise,
   	p.ws,p.hs,
   	av.flipped)
  end
 end

	circfill(av.fist.x*8,av.fist.y*8,av.fist.r*8,av.fist.col)

 --debugging
 print(test,0,0,7)
 printh(test)
end

-->8
--collision utils

function moveavtoflag(flag)
 av.y+=av.yvel
 av.y-=av.y%pixel
 updatehitboxes()
 av.y+=distanceinwall(av.bottom,0,1,-1,flag)+pixel
 updatehitboxes()
end

function moveavtoroof()
 av.y+=distancetowall(av.top,0,1,-1)
 av.y+=pixel-av.y%pixel
end

function moveavtoleft()
 local box={
 	x=av.left.x+coloffset,
 	y=av.left.y,
 	w=av.left.w,
 	h=av.left.h
 }
 
 av.x+=distancetowall(box,1,0,-1)
 av.x+=pixel-av.x%pixel
end

function moveavtoright()
 av.x+=distancetowall(av.right,1,0,1)
 av.x-=av.x%pixel
end

function distancetowall(box,checkx,checky,direction)
 local distancetowall=0

 while not mapcol(box,distancetowall*checkx,distancetowall*checky,0) do
  distancetowall+=(pixel*direction)
 end

 return distancetowall
end

function distanceinwall(box,checkx,checky,direction,flag)
 local distanceinwall=0

 while mapcol
 (box,distanceinwall*checkx,
      distanceinwall*checky,flag) do
  distanceinwall+=(pixel*direction)
 end

 return distanceinwall
end

--stick to wall to give player
-- time to press jump
function stickorfall(sign)
 if (av.onleft or av.onright) and
    av.stickframes>0 then
  av.stickframes-=1
 else
  xaccelerate(av,av.xairacc,sign)
  av.stickframes=av.maxstickframes
 end
end

function xaccelerate(obj,acc,sign)
 if (obj.xvel*sign)<obj.xmaxvel then
  obj.xvel+=acc*sign
 else
  obj.xvel=obj.xmaxvel*sign
 end
end

function avsidecol(box,reaction) 
 if mapcol(box,av.xvel,0,0) then
  av.xvel=0
  
  reaction()

  if not av.onground then
   return true
  end
 end
 return false
end

--mapcollision
function mapcol(box,xvel,yvel,flag)
 return checkflagarea(box.x+xvel,box.y+yvel,box.w,box.h,flag)
end

--need to check more points
-- if h or w are wider than 8px
function checkflagarea(x,y,w,h,flag)
 return
  checkflag(x,y,flag) or
  checkflag(x+(w*0.5),y,flag) or
  checkflag(x+w,y,flag) or
  checkflag(x,y+(h*0.5),flag) or
  checkflag(x,y+h,flag) or
  checkflag(x+(w*0.5),y+h,flag) or
  checkflag(x+w,y+h,flag) or
  checkflag(x+w,y+(h*0.5),flag)
end

function checkflag(x,y,flag)
 val=mget(x, y)
 return fget(val, flag)
end


function updatehitboxes()
 --cover top and bottom
 av.bottom={
 	x=av.x+av.w*0,
 	y=av.y+av.h*pixel*7,
 	w=av.w*pixel*8-coloffset,
 	h=av.h*pixel
 }
 
 av.top={
 	x=av.x+av.w*0,
 	y=av.y+av.h*0,
 	w=av.w*pixel*8-coloffset,
 	h=av.h*pixel
 }
 
 --space between top and bottom
 av.left={
 	x=av.x+av.w*0-coloffset,
 	y=av.y+av.h*pixel,
 	w=av.w*pixel,
 	h=av.h*pixel*6
 }
 
 av.right={
 	x=av.x+av.w*pixel*7,
 	y=av.y+av.h*pixel,
 	w=av.w*pixel,
 	h=av.h*pixel*6
 }
end

function circlecollision(s1,s2)
 local s1x,s1y=s1.x,s1.y
 local s2x,s2y=s2.x,s2.y
 
 if s1.w and s1.h then
  s1x+=(s1.w*0.5)
  s1y+=(s1.h*0.5)
 end
 
 if s2.w and s2.h then
  s2x+=(s2.w*0.5)
  s2y+=(s2.h*0.5)
 end
 
 --get distance from cen to cen
 local dx=s1x-s2x
 local dy=s1y-s2y
 
 local distance=(dx*dx)+(dy*dy)
 
 --if radiuses less than c2c, collision
 if distance<=((s1.r+s2.r)*(s1.r+s2.r)) then
  return true
 end
 return false
end
-->8
--mafs

function movetopoint(obj,xdest,ydest,multi)
 local off=0
 
 local xvec=obj.x-(xdest+off)*(multi or 1)
 local yvec=obj.y-(ydest+off)*(multi or 1)
 
 obj.xvel-=xvec*0.01
 obj.yvel-=yvec*0.01
 
 obj.xvel*=0.9
 obj.yvel*=0.9
 
 obj.x+=obj.xvel
 obj.y+=obj.yvel
end

__gfx__
aaaaaaaa077777700000000033333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c44444487666666700000000bbbbbbbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c44414186666666600000000bbbbbbbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c44444485566555600000000bbbbbbbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c44e44e85555555500000000bbbbbbbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c444ee485555555500000000bbbbbbbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c44444485555555500000000bbbbbbbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
dddddddd5555555500000000bbbbbbbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000bb00000000b00000b000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000b000000000b0bbb0000646655500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000bbbb000000000bbbbb00d5d4655500077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000bbb8bb0000000bb4bb4005544466000077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000bbbbbbb000000bbbbbb066544d44600077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0006bbbbb660000003bbb660d66d444d460005500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06466bbbb00000000033bbb0d666d444670000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
76446bbb760000000000330006666666670000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6644466bb00000000000000000dddd66700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
76444446000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
76655444600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66655676700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666700000000000000044000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
47777667000000000000000044000040004400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4400044000000000000000004400044400444d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4dd004dd00000000000000004dd004d00004d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000b00000b0000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000006466b5bbb00000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000d5d465bbbbb0000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000077444bb4bb40000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000067744dbbbbbb0000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000d77d443bbbbb0000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000d655d4b33bbb0000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000006666333b3300000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000dd333330000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000440333330006000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000440333336466555000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000004dd0333d5d46555000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000055444660000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000066544d446000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000333333d66d444d4633333333000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000bbbbbbd666d44467bbbbbbbb000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000bbbbbbb666666667bbbbbbbb000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000bbbbbbbbdddd667bbbbbbbbb000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbb000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbb000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbb000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbb000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000333333333333333333333333333333330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000333333333333333333333333333333330000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777770077777700777777007777770077777700777777007777770077777700777777007777770077777700777777007777770077777700777777007777770
76666667766666677666666776666667766666677666666776666667766666677666666776666667766666677666666776666667766666677666666776666667
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
55665556556655565566555655665556556655565566555655665556556655565566555655665556556655565566555655665556556655565566555655665556
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555

__gff__
0001000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000100000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000100000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000100000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000100000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000100000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000100000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000100000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000100000000000000030303000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000100000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000100000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000100030303030000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000100000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000100000000000000030303030000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000100000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000100000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
