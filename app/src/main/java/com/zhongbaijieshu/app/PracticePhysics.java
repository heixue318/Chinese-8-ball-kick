package com.zhongbaijieshu.app;

import java.util.ArrayList;

/** Table-space simulation: 2:1 playing surface; distances independent of pixels. */
final class PracticePhysics {
    static final double WIDTH = 2, HEIGHT = 1, R = .022, POCKET = .046;
    static final double[][] POCKETS = {{0,0},{1,0},{2,0},{0,1},{1,1},{2,1}};
    static final class Ball {
        final int number;
        double x, y, vx, vy;
        boolean sunk;
        Ball(int n, double x, double y) { number=n; this.x=x; this.y=y; }
    }
    final ArrayList<Ball> balls = new ArrayList<>();
    private double[] snapshot;
    private double side, follow;
    private boolean firstContact;
    int shots;

    PracticePhysics() { reset(false); }
    void reset(boolean rack) {
        balls.clear(); balls.add(new Ball(0,.5,.5));
        if (rack) {
            int n=0;
            int[] order={1,9,2,10,8,3,11,4,12,5,6,13,7,14,15};
            for(int row=0;row<5;row++) for(int j=0;j<=row;j++)
                balls.add(new Ball(order[n++],1.36+row*R*1.76,.5+(j-row*.5)*R*2.04));
        } else {
            balls.add(new Ball(1,1.45,.5));
            balls.add(new Ball(8,1,.5));
        }
        snapshot=null; shots=0; side=follow=0;
    }
    boolean moving() {
        for(Ball b:balls) if(!b.sunk && Math.hypot(b.vx,b.vy)>.0001) return true;
        return false;
    }
    boolean place(Ball ball,double x,double y) {
        x=Math.max(R,Math.min(WIDTH-R,x)); y=Math.max(R,Math.min(HEIGHT-R,y));
        for(Ball b:balls) if(b!=ball&&!b.sunk&&Math.hypot(x-b.x,y-b.y)<2*R+.001) return false;
        ball.x=x; ball.y=y; ball.sunk=false; snapshot=null; return true;
    }
    void shoot(double heading,double power,double spinX,double spinY,double elevation) {
        if(moving()||power<.02||balls.get(0).sunk) return;
        snapshot=new double[balls.size()*3];
        for(int i=0;i<balls.size();i++) { Ball b=balls.get(i); snapshot[i*3]=b.x; snapshot[i*3+1]=b.y; snapshot[i*3+2]=b.sunk?1:0; }
        double speed=(.25+power*3.4)*Math.cos(Math.toRadians(elevation));
        Ball cue=balls.get(0); cue.vx=Math.cos(heading)*speed; cue.vy=Math.sin(heading)*speed;
        side=spinX; follow=-spinY; firstContact=true; shots++;
    }
    boolean restore() {
        if(snapshot==null) return false;
        for(int i=0;i<balls.size();i++){Ball b=balls.get(i); b.x=snapshot[i*3];b.y=snapshot[i*3+1];b.sunk=snapshot[i*3+2]>0;b.vx=b.vy=0;}
        side=follow=0; return true;
    }
    void step(double dt) {
        // Fixed 240 Hz steps keep fastest ball travel below its radius.
        for(Ball b:balls) {
            if(b.sunk) continue;
            b.x+=b.vx*dt; b.y+=b.vy*dt;
            for(double[] h:POCKETS) if(Math.hypot(b.x-h[0],b.y-h[1])<POCKET) {b.sunk=true;b.vx=b.vy=0;break;}
            if(b.sunk) continue;
            if(b.x<R||b.x>WIDTH-R){b.x=Math.max(R,Math.min(WIDTH-R,b.x));b.vx=-b.vx*.82;if(b.number==0)b.vy+=side*Math.abs(b.vx)*.12;}
            if(b.y<R||b.y>HEIGHT-R){b.y=Math.max(R,Math.min(HEIGHT-R,b.y));b.vy=-b.vy*.82;if(b.number==0)b.vx-=side*Math.abs(b.vy)*.12;}
        }
        for(int i=0;i<balls.size();i++) for(int j=i+1;j<balls.size();j++) {
            Ball a=balls.get(i),b=balls.get(j); if(a.sunk||b.sunk)continue;
            double dx=b.x-a.x,dy=b.y-a.y,d=Math.hypot(dx,dy);
            if(d>=2*R)continue;
            double nx=d<1e-9?1:dx/d,ny=d<1e-9?0:dy/d;
            double overlap=(2*R-d)*.5+.000001;
            a.x-=nx*overlap;a.y-=ny*overlap;b.x+=nx*overlap;b.y+=ny*overlap;
            double relative=(a.vx-b.vx)*nx+(a.vy-b.vy)*ny;
            if(relative<=0)continue;
            double impulse=relative*.97;
            a.vx-=impulse*nx;a.vy-=impulse*ny;b.vx+=impulse*nx;b.vy+=impulse*ny;
            if(firstContact&&a.number==0){a.vx+=nx*relative*follow*.22;a.vy+=ny*relative*follow*.22;firstContact=false;}
        }
        for(Ball b:balls) if(!b.sunk) {
            double speed=Math.hypot(b.vx,b.vy),next=Math.max(0,speed-.32*dt);
            if(next<.008) b.vx=b.vy=0; else {b.vx*=next/speed;b.vy*=next/speed;}
        }
        side*=Math.exp(-dt*.8);
    }
    boolean respotCue() {
        Ball cue=balls.get(0); if(!cue.sunk)return false;
        double[] saved=snapshot;
        for(double x=.2;x<1.9;x+=.06)for(double y=.1;y<.95;y+=.06)if(place(cue,x,y)){snapshot=saved;return true;}
        return false;
    }
}
