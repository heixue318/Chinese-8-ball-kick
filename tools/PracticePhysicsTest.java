package com.zhongbaijieshu.app;

public final class PracticePhysicsTest {
    private static void check(boolean ok,String message){if(!ok)throw new AssertionError(message);}
    private static void settle(PracticePhysics p){int n=0;while(p.moving()&&n++<12000)p.step(1.0/240);check(!p.moving(),"balls must stop");}
    public static void main(String[] args){
        PracticePhysics p=new PracticePhysics();
        p.balls.remove(2);
        p.shoot(0,.5,0,0,0);settle(p);
        check(p.balls.get(1).x>1.45,"head-on collision transfers momentum");
        check(p.restore(),"shot can be restored");
        check(Math.abs(p.balls.get(0).x-.5)<1e-8&&Math.abs(p.balls.get(1).x-1.45)<1e-8,"restore exact positions");
        check(!p.place(p.balls.get(0),1.45,.5),"overlap placement rejected");
        check(p.place(p.balls.get(0),.6,.6),"cue placement accepted");
        check(Math.abs(p.balls.get(1).x-1.45)<1e-8,"cue drag does not move object");
        p.reset(false);p.balls.remove(2);p.balls.remove(1);
        p.balls.get(0).x=1;p.balls.get(0).y=.3;
        p.shoot(-Math.PI/2,.25,0,0,0);settle(p);
        check(p.balls.get(0).sunk,"middle pocket captures cue");
        check(p.respotCue()&&!p.balls.get(0).sunk,"scratch respots cue");
        check(p.restore()&&Math.abs(p.balls.get(0).x-1)<1e-8,"scratch retains shot snapshot");
        p.balls.get(0).x=.5;p.balls.get(0).y=.2;
        p.shoot(-Math.PI/2,.5,0,0,0);
        boolean bounced=false;for(int i=0;i<100;i++){p.step(1.0/240);if(p.balls.get(0).vy>0)bounced=true;}
        check(bounced,"cushion reflects motion");settle(p);
        p.reset(true);check(p.balls.size()==16,"full rack contains 15 objects");
        check(p.balls.get(5).number==8,"eight ball is in the rack center");
        for(int i=0;i<16;i++)for(int j=i+1;j<16;j++)check(Math.hypot(p.balls.get(i).x-p.balls.get(j).x,p.balls.get(i).y-p.balls.get(j).y)>=2*PracticePhysics.R,"rack has no overlaps");
        p.shoot(0,1,.7,-.6,0);settle(p);
        for(PracticePhysics.Ball b:p.balls)check(Double.isFinite(b.x)&&Double.isFinite(b.y),"break remains finite");
        check(p.restore(),"break restore");
        System.out.println("PASS: collision, rest, retry, placement, scratch, cushions, rack and maximum-power break");
    }
}
