package com.zhongbaijieshu.app;

import java.util.*;
import static com.zhongbaijieshu.app.TrainingModel.*;

public final class TrainingTest {
    private static int checks;
    private static void check(boolean value,String message){checks++;if(!value)throw new AssertionError(message);}
    private static void near(double a,double b,String message){check(Math.abs(a-b)<1e-8,message+": "+a+" != "+b);}
    private static Ball ball(int id,double x,double y){return new Ball(id,new Point(x,y),false);}
    private static Layout layout(Ball... balls){return new Layout(Arrays.asList(balls));}
    public static void main(String[] args){
        Table table=new Table(2,1,.022,.046,Arrays.asList(new Point(0,0),new Point(1,0),new Point(2,0),new Point(0,1),new Point(1,1),new Point(2,1)));
        Table closed=new Table(2,1,.022,0,Collections.emptyList());
        Layout direct=layout(ball(0,.4,.5),ball(1,1.2,.5));
        AimGeometry.Trace trace=AimGeometry.trace(table,direct,0,4);
        check(trace.end==AimGeometry.End.BALL&&trace.ballId==1,"First target hit");
        near(trace.ghost.x,1.156,"Ghost center one diameter before target");
        near(trace.contact.x,1.178,"Surface contact one radius before target");
        near(trace.cueSeparation.x,0,"Head-on cue stops");
        trace=AimGeometry.trace(closed,layout(ball(0,.4,.5)),0,4);
        check(trace.cushionCount==4&&trace.segments.size()==5,"Bounded multi-cushion trace");
        near(trace.segments.get(1).to.x,.022,"Second rail");
        trace=AimGeometry.trace(closed,layout(ball(0,.022,.5)),Math.PI,2);
        check(trace.segments.size()==3,"Starting outward on rail remains finite");
        trace=AimGeometry.trace(closed,layout(ball(0,1,.5)),Math.atan2(.478,.978),2);
        check(trace.cushionCount==2,"Corner reflection is finite");
        trace=AimGeometry.trace(table,layout(ball(0,1,.5)), -Math.PI/2,4);
        check(trace.end==AimGeometry.End.POCKET&&trace.cushionCount==0,"Side pocket terminates trace");
        near(trace.segments.get(0).to.y,.046,"Pocket circle entry");
        Layout cut=layout(ball(0,.4,.5),ball(1,1.2,.52));
        trace=AimGeometry.trace(table,cut,0,0);
        near(trace.objectDirection.x*trace.cueSeparation.x+trace.objectDirection.y*trace.cueSeparation.y,0,"Ideal separation perpendicular");
        Table potTable=new Table(2,1,.022,.046,Arrays.asList(new Point(2,.5)));
        AimGeometry.PotAim aim=AimGeometry.potAim(potTable,direct,1,0);
        check(aim.reachable,"Direct pot reachable");near(aim.cutAngle,0,"Straight angle");
        check(!AimGeometry.potAim(potTable,layout(ball(0,.4,.5),ball(1,1.2,.5),ball(8,.8,.5)),1,0).reachable,"Cue route blocker");
        check(!AimGeometry.potAim(potTable,layout(ball(0,.4,.5),ball(1,1.2,.5),ball(8,1.6,.5)),1,0).reachable,"Object route blocker");
        check(!AimGeometry.potAim(potTable,layout(ball(0,1.6,.5),ball(1,1.2,.5)),1,0).reachable,"Backside aim rejected");
        for(TrainingSession.Preset preset:TrainingSession.Preset.values())check(TrainingSession.valid(table,TrainingSession.preset(table,preset)),"Preset valid "+preset);
        for(long seed=0;seed<100;seed++)check(TrainingSession.valid(table,TrainingSession.random(table,15,seed)),"Random layout valid "+seed);
        Layout random=TrainingSession.random(table,15,42),same=TrainingSession.random(table,15,42);
        for(int i=0;i<16;i++)near(random.ball(i).position.x,same.ball(i).position.x,"Seed reproducibility");
        PracticePhysics physics=new PracticePhysics();PracticeTrainingAdapter adapter=new PracticeTrainingAdapter(physics);
        TrainingSession session=new TrainingSession(adapter);session.load(direct);
        Layout immutable=adapter.snapshot();
        check(!session.place(0,new Point(1.2,.5)),"Overlapping placement rejected");
        check(!session.place(0,new Point(-1,.5)),"Outside placement rejected");
        check(session.place(0,new Point(.3,.5)),"Free placement");near(immutable.ball(0).position.x,.4,"Snapshot independent");
        Shot shot=new Shot(0,.3,0,0,0);
        check(session.shoot(shot),"Start shot");check(!session.shoot(shot),"Concurrent shot rejected");
        physics.step(1.0/240);session.capture(1.0/240);
        check(!session.place(1,new Point(1.5,.5)),"Placement locked while moving");
        boolean rejected=false;try{session.capture(0);}catch(IllegalArgumentException expected){rejected=true;}check(rejected,"Monotonic capture time enforced before sampling interval");
        check(session.retry(),"Cancel and retry moving shot");near(physics.balls.get(0).x,.3,"Restored cue");check(!physics.moving(),"Restored velocities");
        check(session.shoot(shot),"Shoot retry");
        double elapsed=0;while(physics.moving()&&elapsed<30){physics.step(1.0/240);elapsed+=1.0/240;session.capture(elapsed);}
        TrainingSession.Review review=session.review();check(review!=null,"Completed review");
        near(review.at(0).ball(0).position.x,.3,"Review starts before shot");
        near(review.at(100).ball(0).position.x,review.after.ball(0).position.x,"Review ends after shot");
        double end=physics.balls.get(0).x;review.at(0);near(physics.balls.get(0).x,end,"Seeking does not mutate engine");
        check(session.retry(),"Completed shot retry");near(physics.balls.get(0).x,.3,"Completed shot start restored");
        for(int angle=0;angle<360;angle++){
            AimGeometry.Trace sweep=AimGeometry.trace(closed,layout(ball(0,1,.5)),Math.toRadians(angle),8);
            check(sweep.segments.size()==9,"Angle sweep terminates");
            for(AimGeometry.Segment segment:sweep.segments)check(segment.to.x>=.022-1e-8&&segment.to.x<=1.978+1e-8&&segment.to.y>=.022-1e-8&&segment.to.y<=.978+1e-8,"Reflections stay on ball-center bounds");
        }
        System.out.println("Training checks passed: "+checks);
    }
}
