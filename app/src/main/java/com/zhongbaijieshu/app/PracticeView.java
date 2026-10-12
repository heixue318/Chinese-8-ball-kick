package com.zhongbaijieshu.app;

import android.graphics.*;
import android.content.Context;
import android.view.MotionEvent;
import android.view.View;
import android.os.Bundle;
import android.view.accessibility.AccessibilityNodeInfo;
import android.view.accessibility.AccessibilityNodeProvider;
import android.widget.Toast;

/** Original free-practice UI; no arcade progression or third-party APK resources. */
final class PracticeView extends View {
    private final PracticePhysics sim=new PracticePhysics();
    private final Paint p=new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF table=new RectF(), powerBar=new RectF(), spin=new RectF(), fineAim=new RectF();
    private final RectF[] buttons=new RectF[8];
    private final String[] labels={"摆球","重试本杆","解球球局","十五球","辅助线","设置","AR 解球","击球"};
    private static final int[] COLORS={0xfffaf7ed,0xffedc341,0xff377acf,0xffdc514c,0xff8757b4,0xffe98c36,0xff399b70,0xffa34153,0xff20242a};
    private float u,k,heading,power=.55f,sx,sy,elevation;
    private boolean editing=false,guides=true;
    private int gesture=-1,pressed=-1,activePointer=-1;
    private PracticePhysics.Ball dragged;
    private float downY, downHeading;
    private long previous;
    private double accumulator;
    private String status="拖动台面瞄准 · 左侧向下拉杆，松手击球";

    public PracticeView(Context context) {super(context); for(int i=0;i<buttons.length;i++)buttons[i]=new RectF();setFocusable(true);}
    @Override protected void onSizeChanged(int w,int h,int oldw,int oldh){
        u=Math.min(w/1000f,h/500f);
        float height=Math.min(h-155*u,(w-190*u)/2);
        k=height; float left=(w-2*height)/2;
        table.set(left,64*u,left+2*height,64*u+height);
        powerBar.set(18*u,104*u,66*u,h-74*u);
        spin.set(w-83*u,96*u,w-17*u,162*u);
        fineAim.set(spin.left+8*u,spin.bottom+99*u,spin.right-8*u,table.bottom-18*u);
        for(int i=0;i<7;i++)buttons[i].set((18+i*112)*u,h-44*u,(122+i*112)*u,h-10*u);
        buttons[7].set(w-126*u,h-44*u,w-18*u,h-10*u);
    }
    @Override protected void onDraw(Canvas c){
        super.onDraw(c);
        if(sim.moving()){
            long now=System.nanoTime();
            if(previous!=0)accumulator+=Math.min(.05,(now-previous)/1e9);
            previous=now;
            while(accumulator>=1.0/240){sim.step(1.0/240);accumulator-=1.0/240;}
            if(!sim.moving()){previous=0;accumulator=0;boolean scratch=sim.respotCue();status=scratch?"母球入袋，已重新摆放 · 可重试本杆":"本杆结束 · 调整方向继续，或重试本杆";}
            else postInvalidateOnAnimation();
        }
        c.drawColor(0xff101b20);
        text(c,"中八解球",24*u,30*u,21,0xfff0e4cb);
        text(c,"自由练习  /  "+(editing?"摆球模式":"击球模式"),168*u,29*u,13,0xff87b5ac);
        text(c,"杆数 "+sim.shots+"   入袋 "+sunkCount(),getWidth()-175*u,29*u,13,0xffe3d1ab);
        drawTable(c);
        drawPower(c);
        drawSpin(c);
        for(int i=0;i<buttons.length;i++){
            p.setColor((i==0&&editing)||(i==4&&guides)||i==7?0xffc6a467:0xff283b43);
            c.drawRoundRect(buttons[i],7*u,7*u,p);
            center(c,labels[i],buttons[i].centerX(),buttons[i].centerY()+4*u,12,i==7?0xff142324:0xfff4ecdd);
        }
        center(c,status,getWidth()/2f,getHeight()-55*u,11,0xffa6b8b6);
    }
    private int sunkCount(){int n=0;for(PracticePhysics.Ball b:sim.balls)if(b.number>0&&b.sunk)n++;return n;}
    private float px(double x){return table.left+(float)x*k;}
    private float py(double y){return table.top+(float)y*k;}
    private void drawTable(Canvas c){
        p.setColor(0xff080e12);c.drawRoundRect(table.left-23*u,table.top-20*u,table.right+23*u,table.bottom+24*u,20*u,20*u,p);
        p.setShader(new LinearGradient(0,table.top-18*u,0,table.bottom+18*u,new int[]{0xff493021,0xff986c41,0xff63442c,0xff39271e},null,Shader.TileMode.CLAMP));c.drawRoundRect(table.left-18*u,table.top-18*u,table.right+18*u,table.bottom+18*u,15*u,15*u,p);p.setShader(null);
        p.setShader(new RadialGradient(table.centerX(),table.centerY(),table.width()*.6f,new int[]{0xff4d7136,0xff344f26,0xff243d1e},null,Shader.TileMode.CLAMP));c.drawRect(table,p);p.setShader(null);
        p.setColor(0xff59773b);p.setStyle(Paint.Style.STROKE);p.setStrokeWidth(7*u);c.drawRect(table,p);p.setStyle(Paint.Style.FILL);
        p.setColor(0xffd5c3a0);for(int i=1;i<8;i++)if(i!=4){c.drawCircle(px(i*.25),table.top-11*u,2*u,p);c.drawCircle(px(i*.25),table.bottom+11*u,2*u,p);}
        for(double[] hole:PracticePhysics.POCKETS){p.setColor(0xffb39462);c.drawCircle(px(hole[0]),py(hole[1]),k*.047f,p);p.setColor(0xff080f13);c.drawCircle(px(hole[0]),py(hole[1]),k*.040f,p);}
        if(!editing&&!sim.moving()){
            if(guides)drawGuide(c);
            PracticePhysics.Ball cue=sim.balls.get(0);
            float dx=(float)Math.cos(heading),dy=(float)Math.sin(heading),gap=k*.045f+(gesture==1?power*45*u:0);
            c.save();c.clipRect(table.left-14*u,table.top-14*u,table.right+14*u,table.bottom+14*u);
            p.setStrokeCap(Paint.Cap.ROUND);p.setStrokeWidth(6*u);p.setColor(0xffd0ad6c);
            c.drawLine(px(cue.x)-dx*gap,py(cue.y)-dy*gap,px(cue.x)-dx*(gap+140*u),py(cue.y)-dy*(gap+140*u),p);
            p.setStrokeWidth(4*u);p.setColor(0xffe6e4d7);c.drawLine(px(cue.x)-dx*gap,py(cue.y)-dy*gap,px(cue.x)-dx*(gap+12*u),py(cue.y)-dy*(gap+12*u),p);p.setStrokeCap(Paint.Cap.BUTT);c.restore();
        }
        for(PracticePhysics.Ball b:sim.balls)if(!b.sunk){
            float x=px(b.x),y=py(b.y),r=(float)PracticePhysics.R*k;
            p.setColor(0x65000000);c.drawCircle(x+2*u,y+3*u,r,p);
            int color=COLORS[b.number==0?0:(b.number-1)%8+1]; p.setColor(Color.WHITE);
            p.setShader(new RadialGradient(x-r*.35f,y-r*.4f,r*1.7f,new int[]{0xffffffff,color,b.number==0?0xff9caaa1:0xff141e22},new float[]{0,.6f,1},Shader.TileMode.CLAMP));c.drawCircle(x,y,r,p);p.setShader(null);
            if(b.number>8){p.setColor(0xfff0eee1);c.drawOval(x-r*.91f,y-r*.5f,x+r*.91f,y+r*.5f,p);}
            if(b.number>0){p.setColor(0xfff5efdf);c.drawCircle(x,y,r*.48f,p);center(c,""+b.number,x,y+r*.22f,r/u*.64f,0xff19242b);}
            if(editing){p.setStyle(Paint.Style.STROKE);p.setStrokeWidth(u);p.setColor(0xffdfc892);c.drawCircle(x,y,r+4*u,p);p.setStyle(Paint.Style.FILL);}
        }
    }
    private void drawGuide(Canvas c){
        PracticePhysics.Ball cue=sim.balls.get(0);double x=cue.x,y=cue.y,dx=Math.cos(heading),dy=Math.sin(heading),r=PracticePhysics.R;
        c.save();c.clipRect(table);p.setColor(0xffeddfad);p.setStrokeWidth(1.4f*u);p.setPathEffect(new DashPathEffect(new float[]{6*u,5*u},0));
        for(int bounce=0;bounce<3;bounce++){
            double wallX=dx>1e-8?(2-r-x)/dx:dx< -1e-8?(r-x)/dx:1e9;
            double wallY=dy>1e-8?(1-r-y)/dy:dy< -1e-8?(r-y)/dy:1e9;
            double t=Math.min(wallX,wallY);PracticePhysics.Ball hit=null;
            for(PracticePhysics.Ball b:sim.balls)if(b.number!=0&&!b.sunk){
                double bx=b.x-x,by=b.y-y,proj=bx*dx+by*dy,disc=4*r*r-(bx*bx+by*by-proj*proj);
                if(disc>=0){double contact=proj-Math.sqrt(disc);if(contact>.00001&&contact<t){t=contact;hit=b;}}
            }
            double ex=x+dx*t,ey=y+dy*t;
            p.setPathEffect(null);p.setColor(0x18eee8bf);p.setStrokeWidth((float)(2*r*k));c.drawLine(px(x),py(y),px(ex),py(ey),p);
            p.setColor(0xffeddfad);p.setStrokeWidth(1.4f*u);p.setPathEffect(new DashPathEffect(new float[]{6*u,5*u},0));c.drawLine(px(x),py(y),px(ex),py(ey),p);
            if(hit!=null){
                p.setPathEffect(null);p.setStyle(Paint.Style.STROKE);c.drawCircle(px(ex),py(ey),(float)r*k,p);p.setStyle(Paint.Style.FILL);
                double nx=(hit.x-ex)/(2*r),ny=(hit.y-ey)/(2*r);
                c.drawLine(px(hit.x),py(hit.y),px(hit.x+nx*.22),py(hit.y+ny*.22),p);
                double normal=dx*nx+dy*ny, tangentX=dx-nx*normal,tangentY=dy-ny*normal;
                p.setColor(0xffb5c6c0);c.drawLine(px(ex),py(ey),px(ex+tangentX*.22),py(ey+tangentY*.22),p);break;
            }
            boolean pocket=false;for(double[] h:PracticePhysics.POCKETS)if(Math.hypot(ex-h[0],ey-h[1])<PracticePhysics.POCKET)pocket=true;
            if(pocket)break;
            if(Math.abs(wallX-wallY)<1e-8){dx=-dx;dy=-dy;}else if(wallX<wallY)dx=-dx;else dy=-dy;
            x=ex+dx*.00001;y=ey+dy*.00001;
        }
        p.setPathEffect(null);c.restore();
    }
    private void drawPower(Canvas c){
        center(c,"力度",powerBar.centerX(),powerBar.top-16*u,12,0xffe5d4b2);
        p.setColor(0xff283e46);c.drawRoundRect(powerBar,12*u,12*u,p);
        p.setColor(0xffc6a467);c.drawRoundRect(powerBar.left+8*u,powerBar.bottom-power*(powerBar.height()-16*u)-8*u,powerBar.right-8*u,powerBar.bottom-8*u,7*u,7*u,p);
        center(c,Math.round(power*100)+"%",powerBar.centerX(),powerBar.bottom+19*u,12,0xffeee0c1);
    }
    private void drawSpin(Canvas c){
        float x=spin.centerX(),y=spin.centerY(),r=spin.width()/2;
        center(c,"母球击点",x,spin.top-15*u,11,0xffd7cbb5);
        p.setColor(0xffefefe5);c.drawCircle(x,y,r,p);p.setColor(0xffbbc2be);p.setStrokeWidth(u);c.drawLine(x-r*.7f,y,x+r*.7f,y,p);c.drawLine(x,y-r*.7f,x,y+r*.7f,p);
        p.setColor(0xffd34c44);c.drawCircle(x+sx*r*.75f,y+sy*r*.75f,4*u,p);
        center(c,"杆角 "+Math.round(elevation)+"°",x,spin.bottom+34*u,11,0xffd7cbb5);
        center(c,"−    /    +",x,spin.bottom+58*u,15,0xffd7cbb5);
        center(c,"方向微调",x,spin.bottom+95*u,11,0xffd7cbb5);
        p.setColor(0xff2c3b40);c.drawRoundRect(fineAim,8*u,8*u,p);
        c.save();c.clipRect(fineAim);p.setColor(0xff96a3a0);p.setStrokeWidth(u);
        float phase=(heading*30*u)%(8*u);
        for(float tick=fineAim.top-8*u+phase;tick<fineAim.bottom;tick+=8*u)c.drawLine(fineAim.left+8*u,tick,fineAim.right-8*u,tick,p);
        c.restore();p.setColor(0xffc6a467);c.drawRoundRect(fineAim.left-3*u,fineAim.centerY()-12*u,fineAim.right+3*u,fineAim.centerY()+12*u,6*u,6*u,p);
        center(c,"↕",fineAim.centerX(),fineAim.centerY()+6*u,20,0xff152527);
    }
    @Override public boolean onTouchEvent(MotionEvent e){
        int action=e.getActionMasked();float x=e.getX(),y=e.getY();
        if(action==MotionEvent.ACTION_DOWN){
            activePointer=e.getPointerId(0);gesture=-1;pressed=-1;downY=y;downHeading=heading;
            for(int i=0;i<buttons.length;i++)if(buttons[i].contains(x,y)){pressed=i;return true;}
            if(sim.moving())return true;
            if(powerBar.contains(x,y)&&!editing){gesture=1;power=0;}
            else if(spin.contains(x,y)){gesture=2;updateSpin(x,y);}
            else if(x>=spin.left&&x<=spin.right&&y>spin.bottom+38*u&&y<spin.bottom+72*u){elevation=Math.max(0,Math.min(60,elevation+(x<spin.centerX()?-5:5)));}
            else if(fineAim.contains(x,y)){gesture=5;}
            else if(table.contains(x,y)){
                if(editing){double nearest=.085;for(PracticePhysics.Ball b:sim.balls)if(!b.sunk){double d=Math.hypot((x-table.left)/k-b.x,(y-table.top)/k-b.y);if(d<nearest){nearest=d;dragged=b;}}if(dragged!=null)gesture=3;}
                else {gesture=4;aim(x,y);}
            }
            invalidate();return true;
        }
        if(action==MotionEvent.ACTION_CANCEL||action==MotionEvent.ACTION_POINTER_DOWN){cancelGesture();return true;}
        if(activePointer<0||e.getPointerId(0)!=activePointer)return true;
        if(action==MotionEvent.ACTION_MOVE){
            if(gesture==1)power=Math.max(0,Math.min(1,(y-downY)/Math.max(1,powerBar.height()*.75f)));
            if(gesture==2)updateSpin(x,y);
            if(gesture==3&&dragged!=null)sim.place(dragged,(x-table.left)/k,(y-table.top)/k);
            if(gesture==4)aim(x,y);
            if(gesture==5)heading=downHeading+(y-downY)/u*.002f;
            invalidate();return true;
        }
        if(action==MotionEvent.ACTION_UP){
            if(gesture==1&&power>=.02)shoot();
            if(pressed>=0&&buttons[pressed].contains(x,y))activate(pressed);
            cancelGesture();performClick();return true;
        }
        return true;
    }
    @Override public boolean performClick(){super.performClick();return true;}
    private void cancelGesture(){gesture=-1;pressed=-1;dragged=null;activePointer=-1;invalidate();}
    private void aim(float x,float y){PracticePhysics.Ball b=sim.balls.get(0);if(Math.hypot(x-px(b.x),y-py(b.y))>k*.04)heading=(float)Math.atan2(y-py(b.y),x-px(b.x));}
    private void updateSpin(float x,float y){sx=(x-spin.centerX())/(spin.width()*.375f);sy=(y-spin.centerY())/(spin.height()*.375f);float length=(float)Math.hypot(sx,sy);if(length>1){sx/=length;sy/=length;}}
    private void activate(int index){
        if(index==5){((MainActivity)getContext()).showSettings();return;}
        if(index==6){Toast.makeText(getContext(),"AR 球台识别尚未接入",Toast.LENGTH_SHORT).show();return;}
        if(sim.moving()&&index!=1)return;
        switch(index){
            case 0:editing=!editing;status=editing?"拖动母球或目标球摆位 · 球体不能重叠":"拖动台面瞄准 · 左侧向下拉杆，松手击球";break;
            case 1:if(sim.restore()){previous=0;accumulator=0;status="已恢复出杆前球局";}else status="尚无可重试的击球";break;
            case 2:case 3:sim.reset(index==3);heading=0;status="球局已重置 · 可切换摆球模式调整位置";break;
            case 4:guides=!guides;break;
            case 7:shoot();break;
        }
    }
    private void shoot(){if(editing){status="请先关闭摆球模式";return;}if(power<.02){status="请向下拉杆蓄力";return;}sim.shoot(heading,power,sx,sy,elevation);previous=System.nanoTime();accumulator=0;status="球体运动中…";postInvalidateOnAnimation();}
    @Override public AccessibilityNodeProvider getAccessibilityNodeProvider(){return accessibility;}
    private final AccessibilityNodeProvider accessibility=new AccessibilityNodeProvider(){
        @Override public AccessibilityNodeInfo createAccessibilityNodeInfo(int id){
            if(id==View.NO_ID){AccessibilityNodeInfo node=AccessibilityNodeInfo.obtain(PracticeView.this);onInitializeAccessibilityNodeInfo(node);node.setContentDescription(status);for(int i=0;i<8;i++)node.addChild(PracticeView.this,i+1);for(int i=0;i<sim.balls.size();i++)if(!sim.balls.get(i).sunk)node.addChild(PracticeView.this,100+i);for(int i=20;i<=23;i++)node.addChild(PracticeView.this,i);return node;}
            AccessibilityNodeInfo node=AccessibilityNodeInfo.obtain();node.setSource(PracticeView.this,id);node.setParent(PracticeView.this);node.setPackageName(getContext().getPackageName());node.setVisibleToUser(isShown());node.setEnabled(true);
            RectF bounds;String description;
            if(id>=1&&id<=8){bounds=buttons[id-1];description=labels[id-1];node.setClassName("android.widget.Button");node.setClickable(true);node.addAction(AccessibilityNodeInfo.ACTION_CLICK);}
            else if(id==20){bounds=powerBar;description="拉杆力度 "+Math.round(power*100)+"%";node.setClassName("android.widget.SeekBar");node.addAction(AccessibilityNodeInfo.ACTION_SCROLL_FORWARD);node.addAction(AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD);}
            else if(id==21){bounds=spin;description="母球击点";node.setClassName("android.view.View");}
            else if(id==22){bounds=table;description="球台瞄准区域";node.setClassName("android.view.View");}
            else if(id==23){bounds=fineAim;description="拖动微调瞄准";node.setClassName("android.widget.SeekBar");node.addAction(AccessibilityNodeInfo.ACTION_SCROLL_FORWARD);node.addAction(AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD);}
            else if(id>=100&&id<100+sim.balls.size()){PracticePhysics.Ball ball=sim.balls.get(id-100);float radius=(float)PracticePhysics.R*k;bounds=new RectF(px(ball.x)-radius,py(ball.y)-radius,px(ball.x)+radius,py(ball.y)+radius);description=ball.number==0?"母球":"目标球 "+ball.number;node.setClassName("android.view.View");}
            else return null;
            node.setContentDescription(description);Rect rect=new Rect();bounds.roundOut(rect);node.setBoundsInParent(rect);int[] location=new int[2];getLocationOnScreen(location);rect.offset(location[0],location[1]);node.setBoundsInScreen(rect);return node;
        }
        @Override public boolean performAction(int id,int action,Bundle args){
            if(id>=1&&id<=8&&action==AccessibilityNodeInfo.ACTION_CLICK){activate(id-1);invalidate();return true;}
            if(id==20&&!sim.moving()&&(action==AccessibilityNodeInfo.ACTION_SCROLL_FORWARD||action==AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD)){power=Math.max(0,Math.min(1,power+(action==AccessibilityNodeInfo.ACTION_SCROLL_FORWARD?.1f:-.1f)));invalidate();return true;}
            if(id==23&&!sim.moving()&&(action==AccessibilityNodeInfo.ACTION_SCROLL_FORWARD||action==AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD)){heading+=(action==AccessibilityNodeInfo.ACTION_SCROLL_FORWARD?1:-1)*Math.PI/720;invalidate();return true;}
            return false;
        }
    };
    @Override protected void onWindowVisibilityChanged(int visibility){super.onWindowVisibilityChanged(visibility);previous=0;accumulator=0;if(visibility==VISIBLE)invalidate();}
    private void text(Canvas c,String value,float x,float y,float size,int color){p.setColor(color);p.setTextSize(size*u);p.setTypeface(Typeface.create("sans-serif",Typeface.NORMAL));p.setTextAlign(Paint.Align.LEFT);c.drawText(value,x,y,p);}
    private void center(Canvas c,String value,float x,float y,float size,int color){p.setColor(color);p.setTextSize(size*u);p.setTypeface(Typeface.create("sans-serif",Typeface.NORMAL));p.setTextAlign(Paint.Align.CENTER);c.drawText(value,x,y,p);p.setTextAlign(Paint.Align.LEFT);}
}
