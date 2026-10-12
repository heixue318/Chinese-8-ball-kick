package com.zhongbaijieshu.app;

import java.util.*;
import static com.zhongbaijieshu.app.TrainingModel.*;

/** Adapter for the current approximate engine. Future engines implement TrainingModel.Engine. */
final class PracticeTrainingAdapter implements Engine {
    private final PracticePhysics physics;
    PracticeTrainingAdapter(PracticePhysics physics){this.physics=Objects.requireNonNull(physics);}
    @Override public Table table(){
        List<Point> pockets=new ArrayList<>();
        for(double[] p:PracticePhysics.POCKETS)pockets.add(new Point(p[0],p[1]));
        return new Table(PracticePhysics.WIDTH,PracticePhysics.HEIGHT,PracticePhysics.R,PracticePhysics.POCKET,pockets);
    }
    @Override public Layout snapshot(){
        List<Ball> balls=new ArrayList<>();
        for(PracticePhysics.Ball b:physics.balls)balls.add(new Ball(b.number,new Point(b.x,b.y),b.sunk));
        return new Layout(balls);
    }
    @Override public boolean moving(){return physics.moving();}
    @Override public void restore(Layout layout){
        int shots=physics.shots;
        physics.reset(false);physics.balls.clear();
        // Existing engine identifies cue by index, independent of external layout order.
        append(layout.ball(0));
        for(Ball b:layout.balls)if(b.id!=0)append(b);
        physics.shots=shots;
    }
    private void append(Ball b){PracticePhysics.Ball live=new PracticePhysics.Ball(b.id,b.position.x,b.position.y);live.sunk=b.pocketed;physics.balls.add(live);}
    @Override public boolean shoot(Shot shot){
        if(physics.moving()||shot.power<.02||physics.balls.get(0).sunk)return false;
        physics.shoot(shot.heading,shot.power,shot.spinX,shot.spinY,shot.elevation);return true;
    }
}
