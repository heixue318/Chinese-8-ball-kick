package com.zhongbaijieshu.app;

import java.util.*;
import static com.zhongbaijieshu.app.TrainingModel.*;

/** Placement, repeatable drills and bounded immutable shot review, separate from simulation. */
public final class TrainingSession {
    public enum Preset { STRAIGHT, CUT, ONE_CUSHION, TWO_CUSHION }
    public static final class Frame {
        public final double seconds;
        public final Layout layout;
        Frame(double seconds,Layout layout){this.seconds=seconds;this.layout=layout;}
    }
    public static final class Review {
        public final Layout before,after;
        public final Shot shot;
        public final List<Frame> frames;
        Review(Layout before,Layout after,Shot shot,List<Frame> frames){this.before=before;this.after=after;this.shot=shot;this.frames=Collections.unmodifiableList(new ArrayList<>(frames));}
        /** Recorded frame at or immediately before time; seeking never mutates the engine. */
        public Layout at(double seconds) {
            if(!Double.isFinite(seconds))throw new IllegalArgumentException("Invalid review time");
            Layout result=before;
            for(Frame frame:frames){if(frame.seconds>seconds)break;result=frame.layout;}
            return result;
        }
    }
    private final Engine engine;
    private Layout before;
    private Shot shot;
    private final List<Frame> frames=new ArrayList<>();
    private Review review;
    private double lastTime,observedTime;
    private boolean recording;
    public TrainingSession(Engine engine){this.engine=Objects.requireNonNull(engine);}
    public boolean place(int id,Point position) {
        if(engine.moving()||recording)return false;
        Layout original=engine.snapshot();original.ball(id);
        List<Ball> balls=new ArrayList<>();
        for(Ball b:original.balls)balls.add(b.id==id?new Ball(id,position,false):b);
        Layout changed=new Layout(balls);
        if(!valid(engine.table(),changed))return false;
        engine.restore(changed);clear();return true;
    }
    public void load(Layout layout) {
        if(engine.moving()||recording)throw new IllegalStateException("Finish or retry the current shot first");
        if(!valid(engine.table(),layout))throw new IllegalArgumentException("Invalid training layout");
        engine.restore(layout);clear();
    }
    public boolean shoot(Shot controls) {
        if(engine.moving()||recording)return false;
        Layout candidate=engine.snapshot();
        if(!engine.shoot(controls))return false;
        before=candidate;shot=controls;frames.clear();frames.add(new Frame(0,before));lastTime=0;observedTime=0;recording=true;review=null;return true;
    }
    /** Call after simulation advances, BEFORE automatic cue respot, with elapsed shot time. */
    public void capture(double seconds) {
        if(!recording)return;
        if(!Double.isFinite(seconds)||seconds<observedTime)throw new IllegalArgumentException("Monotonic elapsed time required");
        observedTime=seconds;
        Layout current=engine.snapshot();
        boolean finished=!engine.moving();
        if(seconds-lastTime>=1.0/30||finished){
            if(frames.size()>=1800){ // Decimate old frames, retaining both start and latest state.
                for(int i=frames.size()-2;i>0;i-=2)frames.remove(i);
            }
            frames.add(new Frame(seconds,current));lastTime=seconds;
        }
        if(finished){review=new Review(before,current,shot,frames);recording=false;}
    }
    /** Cancels a moving shot and resets all simulation state through the adapter. */
    public boolean retry(){if(before==null)return false;engine.restore(before);recording=false;frames.clear();return true;}
    public Review review(){return review;}
    public Shot lastShot(){return shot;}
    private void clear(){before=null;shot=null;review=null;frames.clear();recording=false;lastTime=0;observedTime=0;}
    public static boolean valid(Table table,Layout layout) {
        for(int i=0;i<layout.balls.size();i++) {
            Ball b=layout.balls.get(i);if(b.pocketed)continue;
            if(!table.contains(b.position))return false;
            for(Point pocket:table.pockets)if(b.position.distance(pocket)<table.pocketRadius)return false;
            for(int j=0;j<i;j++){Ball a=layout.balls.get(j);if(!a.pocketed&&a.position.distance(b.position)<2*table.radius+1e-6)return false;}
        }
        return !layout.ball(0).pocketed;
    }
    public static Layout preset(Table table,Preset preset) {
        double[][] coords;
        switch(preset){
            case STRAIGHT:coords=new double[][]{{.25,.75},{.65,.35}};break;
            case CUT:coords=new double[][]{{.25,.72},{.66,.4}};break;
            case ONE_CUSHION:coords=new double[][]{{.25,.65},{.75,.65},{.5,.65}};break;
            default:coords=new double[][]{{.22,.72},{.77,.28},{.5,.5}};
        }
        List<Ball> balls=new ArrayList<>();
        for(int i=0;i<coords.length;i++)balls.add(new Ball(i==2?8:i,new Point(coords[i][0]*table.width,coords[i][1]*table.height),false));
        Layout layout=new Layout(balls);if(!valid(table,layout))throw new IllegalArgumentException("Preset does not fit this table");return layout;
    }
    /** Same table/count/seed yields the same layout. Throws explicitly if density is infeasible. */
    public static Layout random(Table table,int objectCount,long seed) {
        if(objectCount<1||objectCount>15)throw new IllegalArgumentException("Object count must be 1..15");
        Random random=new Random(seed);List<Ball> balls=new ArrayList<>();
        for(int id=0;id<=objectCount;id++) {
            boolean placed=false;
            for(int attempt=0;attempt<10000;attempt++){
                Point p=new Point(table.radius+random.nextDouble()*(table.width-2*table.radius),table.radius+random.nextDouble()*(table.height-2*table.radius));
                boolean free=true;
                for(Point pocket:table.pockets)if(p.distance(pocket)<table.pocketRadius+table.radius)free=false;
                for(Ball ball:balls)if(p.distance(ball.position)<2*table.radius+.001)free=false;
                if(free){balls.add(new Ball(id,p,false));placed=true;break;}
            }
            if(!placed)throw new IllegalArgumentException("Unable to fit requested balls");
        }
        return new Layout(balls);
    }
}
