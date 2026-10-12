package com.zhongbaijieshu.app;

import java.util.*;
import static com.zhongbaijieshu.app.TrainingModel.*;

/** Ideal equal-radius, equal-mass geometry only: no throw, spin, friction or jaw physics. */
public final class AimGeometry {
    private static final double EPS=1e-9;
    private AimGeometry() {}
    public enum End { BALL, POCKET, CUSHION_LIMIT }
    public static final class Segment {
        public final Point from,to;
        Segment(Point from,Point to){this.from=from;this.to=to;}
    }
    public static final class PotAim {
        public final Point ghost,contact,objectDirection;
        public final double heading,cutAngle;
        public final boolean reachable;
        PotAim(Point ghost,Point contact,Point direction,double heading,double cutAngle,boolean reachable) {
            this.ghost=ghost;this.contact=contact;this.objectDirection=direction;this.heading=heading;this.cutAngle=cutAngle;this.reachable=reachable;
        }
    }
    public static final class Trace {
        public final List<Segment> segments;
        public final End end;
        public final int ballId,cushionCount;
        public final Point ghost,contact,objectDirection,cueSeparation;
        Trace(List<Segment> segments,End end,int ballId,int cushions,Point ghost,Point contact,Point objectDirection,Point cueSeparation) {
            this.segments=Collections.unmodifiableList(new ArrayList<>(segments));this.end=end;this.ballId=ballId;this.cushionCount=cushions;
            this.ghost=ghost;this.contact=contact;this.objectDirection=objectDirection;this.cueSeparation=cueSeparation;
        }
    }
    public static PotAim potAim(Table table,Layout layout,int targetId,int pocketIndex) {
        Ball cue=layout.ball(0),object=layout.ball(targetId);
        if(targetId==0||cue.pocketed||object.pocketed)throw new IllegalArgumentException("Active cue and target required");
        Point pocket=table.pockets.get(pocketIndex),n=unit(pocket.x-object.position.x,pocket.y-object.position.y);
        Point ghost=new Point(object.position.x-2*table.radius*n.x,object.position.y-2*table.radius*n.y);
        Point contact=new Point(object.position.x-table.radius*n.x,object.position.y-table.radius*n.y);
        Point incoming=unit(ghost.x-cue.position.x,ghost.y-cue.position.y);
        double dot=incoming.x*n.x+incoming.y*n.y;
        boolean reachable=table.contains(ghost)&&dot>EPS;
        for(Ball b:layout.balls)if(!b.pocketed&&b.id!=0&&b.id!=targetId) {
            if(distanceToSegment(b.position,cue.position,ghost)<2*table.radius-EPS||distanceToSegment(b.position,object.position,pocket)<2*table.radius-EPS)reachable=false;
        }
        return new PotAim(ghost,contact,n,Math.atan2(incoming.y,incoming.x),Math.acos(Math.max(-1,Math.min(1,dot))),reachable);
    }
    /** maxCushions reflections, then a final segment; stops on the first ball or pocket capture circle. */
    public static Trace trace(Table table,Layout layout,double heading,int maxCushions) {
        if(!Double.isFinite(heading)||maxCushions<0||maxCushions>32)throw new IllegalArgumentException("Invalid trace limits");
        Ball cue=layout.ball(0);
        if(cue.pocketed||!table.contains(cue.position))throw new IllegalArgumentException("Cue must be on table");
        Point start=cue.position;double dx=Math.cos(heading),dy=Math.sin(heading);int cushions=0;
        List<Segment> segments=new ArrayList<>();
        while(true) {
            double tx=dx>EPS?(table.width-table.radius-start.x)/dx:dx< -EPS?(table.radius-start.x)/dx:Double.POSITIVE_INFINITY;
            double ty=dy>EPS?(table.height-table.radius-start.y)/dy:dy< -EPS?(table.radius-start.y)/dy:Double.POSITIVE_INFINITY;
            double distance=Math.min(tx,ty);Ball hit=null;boolean pocket=false;
            for(Ball b:layout.balls)if(b.id!=0&&!b.pocketed) {
                double t=rayCircle(start,dx,dy,b.position,2*table.radius);
                if(t<=distance+EPS){distance=t;hit=b;}
            }
            for(Point p:table.pockets) {
                double t=rayCircle(start,dx,dy,p,table.pocketRadius);
                if(t<distance-EPS){distance=t;hit=null;pocket=true;}
            }
            Point end=new Point(start.x+dx*distance,start.y+dy*distance);segments.add(new Segment(start,end));
            if(hit!=null) {
                Point n=unit(hit.position.x-end.x,hit.position.y-end.y);
                double normal=dx*n.x+dy*n.y;
                return new Trace(segments,End.BALL,hit.id,cushions,end,new Point(end.x+n.x*table.radius,end.y+n.y*table.radius),n,new Point(dx-normal*n.x,dy-normal*n.y));
            }
            if(pocket)return new Trace(segments,End.POCKET,-1,cushions,null,null,null,null);
            if(cushions==maxCushions)return new Trace(segments,End.CUSHION_LIMIT,-1,cushions,null,null,null,null);
            if(Math.abs(tx-ty)<EPS){dx=-dx;dy=-dy;}else if(tx<ty)dx=-dx;else dy=-dy;
            cushions++;start=end;
        }
    }
    private static double rayCircle(Point origin,double dx,double dy,Point center,double radius) {
        double x=center.x-origin.x,y=center.y-origin.y,projection=x*dx+y*dy;
        double discriminant=radius*radius-(x*x+y*y-projection*projection);
        if(discriminant< -EPS)return Double.POSITIVE_INFINITY;
        double t=projection-Math.sqrt(Math.max(0,discriminant));
        if(t>=-EPS&&projection>EPS)return Math.max(0,t);
        return Double.POSITIVE_INFINITY;
    }
    private static Point unit(double x,double y){double length=Math.hypot(x,y);if(length<EPS)throw new IllegalArgumentException("Coincident points");return new Point(x/length,y/length);}
    private static double distanceToSegment(Point p,Point a,Point b){double dx=b.x-a.x,dy=b.y-a.y,d=dx*dx+dy*dy,t=d<EPS?0:Math.max(0,Math.min(1,((p.x-a.x)*dx+(p.y-a.y)*dy)/d));return Math.hypot(p.x-a.x-t*dx,p.y-a.y-t*dy);}
}
