package com.zhongbaijieshu.app;

import java.util.*;

/** Immutable engine-neutral training state. Coordinates use the table's own length unit. */
public final class TrainingModel {
    private TrainingModel() {}
    public static final class Point {
        public final double x, y;
        public Point(double x, double y) {
            if (!Double.isFinite(x) || !Double.isFinite(y)) throw new IllegalArgumentException("Non-finite point");
            this.x=x; this.y=y;
        }
        public double distance(Point p) { return Math.hypot(x-p.x,y-p.y); }
    }
    public static final class Ball {
        public final int id;
        public final Point position;
        public final boolean pocketed;
        public Ball(int id, Point position, boolean pocketed) {
            if(id<0 || position==null) throw new IllegalArgumentException("Invalid ball");
            this.id=id;this.position=position;this.pocketed=pocketed;
        }
    }
    public static final class Table {
        public final double width,height,radius,pocketRadius;
        public final List<Point> pockets;
        public Table(double width,double height,double radius,double pocketRadius,List<Point> pockets) {
            if(!Double.isFinite(width+height+radius+pocketRadius)||radius<=0||width<=2*radius||height<=2*radius||pocketRadius<0)
                throw new IllegalArgumentException("Invalid table dimensions");
            this.width=width;this.height=height;this.radius=radius;this.pocketRadius=pocketRadius;
            this.pockets=Collections.unmodifiableList(new ArrayList<>(pockets));
        }
        public boolean contains(Point p) {
            return p.x>=radius&&p.x<=width-radius&&p.y>=radius&&p.y<=height-radius;
        }
    }
    public static final class Layout {
        public final List<Ball> balls;
        public Layout(List<Ball> balls) {
            Set<Integer> ids=new HashSet<>();
            for(Ball b:balls) if(!ids.add(b.id)) throw new IllegalArgumentException("Duplicate ball id");
            if(!ids.contains(0)) throw new IllegalArgumentException("Cue ball id 0 required");
            this.balls=Collections.unmodifiableList(new ArrayList<>(balls));
        }
        public Ball ball(int id) {
            for(Ball b:balls) if(b.id==id) return b;
            throw new IllegalArgumentException("Unknown ball: "+id);
        }
    }
    public static final class Shot {
        public final double heading,power,spinX,spinY,elevation;
        public Shot(double heading,double power,double spinX,double spinY,double elevation) {
            if(!Double.isFinite(heading+power+spinX+spinY+elevation)||power<0||power>1||Math.hypot(spinX,spinY)>1+1e-9||elevation<0||elevation>60)
                throw new IllegalArgumentException("Invalid shot controls");
            this.heading=heading;this.power=power;this.spinX=spinX;this.spinY=spinY;this.elevation=elevation;
        }
    }
    /** Adapters reset all velocity/spin/contact state on restore; snapshots must not alias live state. */
    public interface Engine {
        Table table();
        Layout snapshot();
        boolean moving();
        void restore(Layout layout);
        boolean shoot(Shot shot);
    }
}
