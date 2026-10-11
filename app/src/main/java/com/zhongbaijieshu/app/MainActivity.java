package com.zhongbaijieshu.app;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.DownloadManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.os.Build;
import android.database.Cursor;
import android.widget.Toast;
import android.view.View;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RectF;
import android.graphics.Color;
import android.view.MotionEvent;
import org.json.JSONObject;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.ArrayList;

public class MainActivity extends Activity {
    private static final String UPDATE_URL = "https://raw.githubusercontent.com/heixue318/Chinese-8-ball-kick/main/update.json";
    private long updateDownloadId = -1;
    private Uri pendingInstallUri;
    private boolean waitingInstallPermission;
    private BroadcastReceiver downloadReceiver;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_FULLSCREEN | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION);
        setContentView(new TableView(this));
        downloadReceiver = new BroadcastReceiver() {
            @Override public void onReceive(Context context, Intent intent) {
                if (!DownloadManager.ACTION_DOWNLOAD_COMPLETE.equals(intent.getAction())) return;
                long id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1);
                if (id == updateDownloadId) finishDownload(id);
            }
        };
        IntentFilter filter = new IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE);
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(downloadReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
        else registerReceiver(downloadReceiver, filter);
    }

    @Override protected void onResume() {
        super.onResume();
        if (waitingInstallPermission && Build.VERSION.SDK_INT >= 26 && getPackageManager().canRequestPackageInstalls()) {
            waitingInstallPermission = false;
            openInstaller();
        }
    }

    @Override protected void onDestroy() {
        if (downloadReceiver != null) unregisterReceiver(downloadReceiver);
        super.onDestroy();
    }

    void checkForUpdates() {
        Toast.makeText(this, "正在检查更新…", Toast.LENGTH_SHORT).show();
        new Thread(() -> {
            HttpURLConnection connection = null;
            try {
                connection = (HttpURLConnection) new URL(UPDATE_URL).openConnection();
                connection.setConnectTimeout(10000);
                connection.setReadTimeout(10000);
                connection.setRequestProperty("User-Agent", "ZhongBaJieQiu-Android");
                connection.setRequestProperty("Accept", "application/json");
                if (connection.getResponseCode() != 200) throw new IllegalStateException("更新服务器暂时无法访问");
                BufferedReader reader = new BufferedReader(new InputStreamReader(connection.getInputStream(), "UTF-8"));
                StringBuilder body = new StringBuilder();
                String line;
                while ((line = reader.readLine()) != null) body.append(line);
                reader.close();
                JSONObject latest = new JSONObject(body.toString());
                int latestCode = latest.getInt("versionCode");
                String latestName = latest.getString("versionName");
                String apkUrl = latest.getString("apkUrl");
                String notes = latest.optString("releaseNotes", "修复问题并改进体验");
                int currentCode = getPackageManager().getPackageInfo(getPackageName(), 0).versionCode;
                runOnUiThread(() -> {
                    if (latestCode <= currentCode) {
                        Toast.makeText(this, "当前已是最新版本", Toast.LENGTH_LONG).show();
                    } else {
                        new AlertDialog.Builder(this).setTitle("发现新版本 " + latestName)
                                .setMessage(notes + "\n\n安装时 Android 会要求你确认。")
                                .setNegativeButton("稍后", null)
                                .setPositiveButton("下载并安装", (dialog, which) -> downloadUpdate(apkUrl, latestName))
                                .show();
                    }
                });
            } catch (Exception ex) {
                runOnUiThread(() -> Toast.makeText(this, "检查更新失败：" + ex.getMessage(), Toast.LENGTH_LONG).show());
            } finally {
                if (connection != null) connection.disconnect();
            }
        }).start();
    }

    private void downloadUpdate(String apkUrl, String versionName) {
        try {
            DownloadManager manager = (DownloadManager) getSystemService(DOWNLOAD_SERVICE);
            DownloadManager.Request request = new DownloadManager.Request(Uri.parse(apkUrl));
            request.setTitle("中八解球 " + versionName);
            request.setDescription("正在下载更新安装包");
            request.setMimeType("application/vnd.android.package-archive");
            request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
            request.setDestinationInExternalFilesDir(this, Environment.DIRECTORY_DOWNLOADS, "zhongbaijieshu-" + versionName + ".apk");
            updateDownloadId = manager.enqueue(request);
            Toast.makeText(this, "已开始下载，完成后会打开安装确认", Toast.LENGTH_LONG).show();
        } catch (Exception ex) {
            Toast.makeText(this, "无法开始下载：" + ex.getMessage(), Toast.LENGTH_LONG).show();
        }
    }

    private void finishDownload(long id) {
        DownloadManager manager = (DownloadManager) getSystemService(DOWNLOAD_SERVICE);
        DownloadManager.Query query = new DownloadManager.Query().setFilterById(id);
        try (Cursor cursor = manager.query(query)) {
            if (cursor == null || !cursor.moveToFirst()) return;
            int status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS));
            if (status != DownloadManager.STATUS_SUCCESSFUL) {
                Toast.makeText(this, "安装包下载失败，请检查网络后重试", Toast.LENGTH_LONG).show();
                return;
            }
            pendingInstallUri = manager.getUriForDownloadedFile(id);
            if (pendingInstallUri != null) openInstaller();
        }
    }

    private void openInstaller() {
        if (pendingInstallUri == null) return;
        if (Build.VERSION.SDK_INT >= 26 && !getPackageManager().canRequestPackageInstalls()) {
            waitingInstallPermission = true;
            Toast.makeText(this, "请允许中八解球安装本次更新，返回后会继续", Toast.LENGTH_LONG).show();
            Intent settings = new Intent(android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:" + getPackageName()));
            startActivity(settings);
            return;
        }
        Intent install = new Intent(Intent.ACTION_VIEW);
        install.setDataAndType(pendingInstallUri, "application/vnd.android.package-archive");
        install.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_ACTIVITY_NEW_TASK);
        startActivity(install);
        pendingInstallUri = null;
    }

    static class Ball { float x,y; int color; String label; Ball(float x,float y,int c,String l){this.x=x;this.y=y;color=c;label=l;} }

    static class TableView extends View {
        final Paint p = new Paint(3);
        final ArrayList<Ball> balls = new ArrayList<>();
        int selected=1, spin=4; float angle=0, power=.52f;
        boolean ar=false, dragging=false, powerDragging=false;
        float W,H,tx,ty,tw,th, panelX,panelY,panelW,panelH, scale, downX,downY;
        RectF strike=new RectF(), reset=new RectF(), modeFree=new RectF(), modeAr=new RectF(), updateButton=new RectF(), angleMinus=new RectF(), anglePlus=new RectF(), powerMinus=new RectF(), powerPlus=new RectF();
        RectF[] spinCells = new RectF[9];
        final int felt=Color.rgb(16,112,82), gold=Color.rgb(219,174,94), ivory=Color.rgb(250,244,223), dark=Color.rgb(18,26,24), white=Color.WHITE;
        TableView(Activity a){super(a); setLayerType(View.LAYER_TYPE_SOFTWARE,null); initBalls(); for(int i=0;i<9;i++)spinCells[i]=new RectF();}
        void initBalls(){balls.clear(); balls.add(new Ball(.27f,.52f,Color.rgb(247,243,224),"母"));
            int[] c={0xffe4bc43,0xff3c8ccb,0xffd9534f,0xff7b58a6,0xffee8a38,0xff44966c,0xff9c4556,0xff171717};
            String[] n={"1","2","3","4","5","6","7","8"};
            float[][] pos={{.70f,.50f},{.73f,.46f},{.73f,.54f},{.76f,.42f},{.76f,.50f},{.76f,.58f},{.79f,.46f},{.79f,.54f}};
            for(int i=0;i<8;i++)balls.add(new Ball(pos[i][0],pos[i][1],c[i],n[i])); selected=1; invalidate(); }
        @Override protected void onDraw(Canvas c){super.onDraw(c); W=getWidth();H=getHeight(); c.drawColor(dark);
            boolean landscape=W>H; float pad=Math.min(W,H)*.035f; float header=Math.max(54,Math.min(W,H)*.105f);
            text(c,"中八解球",pad,header*.64f,header*.42f,ivory,true); text(c,ar?"AR 识别待接入":"自由练习",pad,header*.92f,Math.max(11,header*.20f),0xff9dada7,false);
            modeFree.set(W-pad-245,header*.20f,W-pad-163,header*.78f); modeAr.set(W-pad-155,header*.20f,W-pad-93,header*.78f); updateButton.set(W-pad-85,header*.20f,W-pad,header*.78f);
            button(c,modeFree,"练习",!ar); button(c,modeAr,"AR",ar); button(c,updateButton,"更新",false);
            if(landscape){ panelW=Math.max(205,Math.min(275,W*.29f)); panelX=W-pad-panelW; panelY=header+pad; panelH=H-header-2*pad;
                tx=pad; ty=header+pad+14; tw=panelX-tx-pad; th=Math.min(panelH,tw*.53f); ty+=(panelH-th)*.5f;
            } else { panelX=pad; panelY=header+pad; panelW=W-2*pad; panelH=H-panelY-pad; tx=pad; tw=W-2*pad; th=Math.min(H*.38f,tw*.53f); ty=panelY+Math.max(0,(panelH-th)*.22f); }
            drawTable(c); drawPanel(c,landscape);
        }
        void drawTable(Canvas c){float rail=Math.max(10,Math.min(tw,th)*.045f); p.setColor(0xff503827); c.drawRoundRect(tx-rail,ty-rail,tx+tw+rail,ty+th+rail,rail*.6f,rail*.6f,p);
            p.setColor(felt); c.drawRect(tx,ty,tx+tw,ty+th,p); p.setColor(0xffb4d6bb);p.setStyle(Paint.Style.STROKE);p.setStrokeWidth(1.2f);c.drawRect(tx,ty,tx+tw,ty+th,p);p.setStyle(Paint.Style.FILL);
            float r=Math.max(5,Math.min(tw,th)*.025f); float[][] pockets={{tx,ty},{tx+tw/2,ty},{tx+tw,ty},{tx,ty+th},{tx+tw/2,ty+th},{tx+tw,ty+th}};
            for(float[] q:pockets){p.setColor(0xff0b0d0c);c.drawCircle(q[0],q[1],r*1.45f,p);}
            Ball cue=balls.get(0), target=balls.get(Math.min(selected,balls.size()-1)); float cx=tx+cue.x*tw,cy=ty+cue.y*th, ox=tx+target.x*tw,oy=ty+target.y*th;
            float dx=ox-cx,dy=oy-cy,len=(float)Math.hypot(dx,dy); if(len>0){dx/=len;dy/=len; float br=Math.max(5,Math.min(tw,th)*.022f);
                dashed(c,cx,cy,ox-dx*br*1.7f,oy-dy*br*1.7f,0xfff7e9b0,br*.18f);
                float endX=ox+dx*tw*.33f,endY=oy+dy*tw*.33f; float[] hit=rayLimit(ox,oy,dx,dy,br);
                if(hit!=null){endX=hit[0];endY=hit[1];}
                dashed(c,ox+dx*br*1.7f,oy+dy*br*1.7f,endX,endY,0xffffd278,br*.18f);
            }
            for(int i=0;i<balls.size();i++){Ball b=balls.get(i); float x=tx+b.x*tw,y=ty+b.y*th, br=Math.max(6,Math.min(tw,th)*.025f);
                p.setColor(0x55000000);c.drawCircle(x+br*.15f,y+br*.18f,br,p);p.setColor(b.color);c.drawCircle(x,y,br,p);
                if(i==selected){p.setColor(gold);p.setStyle(Paint.Style.STROKE);p.setStrokeWidth(2);c.drawCircle(x,y,br+3,p);p.setStyle(Paint.Style.FILL);}
                if(i==0){p.setColor(0xff746f62);p.setTextAlign(Paint.Align.CENTER);p.setTextSize(br*.78f);c.drawText("●",x,y+br*.28f,p);} else {p.setColor(i==8?white:0xff17211d);p.setTextAlign(Paint.Align.CENTER);p.setTextSize(br*.8f);c.drawText(b.label,x,y+br*.28f,p);}
            }
            if(ar){p.setColor(0xd9121a18);c.drawRoundRect(tx+tw*.15f,ty+th*.31f,tx+tw*.85f,ty+th*.69f,16,16,p);textCentered(c,"AR 相机识别尚未接入",tx+tw*.5f,ty+th*.46f,Math.max(14,Math.min(19,tw*.038f)),ivory,true);textCentered(c,"当前版本可使用自由练习摆球",tx+tw*.5f,ty+th*.57f,Math.max(11,Math.min(14,tw*.027f)),0xffb4c3bc,false);}
            p.setTextAlign(Paint.Align.LEFT); text(c,"虚线：母球路线   金线：目标球路线",tx,ty+th+rail+20,12,0xffb4c3bc,false);
        }
        float[] rayLimit(float x,float y,float dx,float dy,float margin){float best=Float.POSITIVE_INFINITY, bx=0,by=0; float[] xs={tx+margin,tx+tw-margin},ys={ty+margin,ty+th-margin};
            if(dx>0){float t=(xs[1]-x)/dx;if(t>0&&t<best){best=t;bx=xs[1];by=y+dy*t;}} else if(dx<0){float t=(xs[0]-x)/dx;if(t>0&&t<best){best=t;bx=xs[0];by=y+dy*t;}}
            if(dy>0){float t=(ys[1]-y)/dy;if(t>0&&t<best){best=t;bx=x+dx*t;by=ys[1];}} else if(dy<0){float t=(ys[0]-y)/dy;if(t>0&&t<best){best=t;bx=x+dx*t;by=ys[0];}}
            return best<Float.POSITIVE_INFINITY?new float[]{bx,by}:null; }
        void dashed(Canvas c,float x1,float y1,float x2,float y2,int color,float width){float d=(float)Math.hypot(x2-x1,y2-y1);int n=Math.max(1,(int)(d/10));p.setColor(color);p.setStrokeWidth(width);for(int i=0;i<n;i+=2){float a=i/(float)n,b=Math.min(1,(i+1)/(float)n);c.drawLine(x1+(x2-x1)*a,y1+(y2-y1)*a,x1+(x2-x1)*b,y1+(y2-y1)*b,p);}}
        void drawPanel(Canvas c,boolean landscape){float gap=10; float x=panelX,y=panelY,w=panelW; p.setColor(0xff202b27);c.drawRoundRect(x,y,x+w,y+panelH,20,20,p);
            float fs=Math.max(12,Math.min(16,w*.065f)); float top=y+18;
            text(c,"母球击点",x+16,top+fs,fs,ivory,true); float cell=Math.min(34,w*.14f), gx=x+w*.52f, gy=top+fs+13;
            for(int i=0;i<9;i++){int row=i/3,col=i%3;RectF r=new RectF(gx+(cell+5)*col,gy+(cell+5)*row,gx+(cell+5)*col+cell,gy+(cell+5)*row+cell);spinCells[i].set(r);p.setColor(spin==i?0xff4a806a:0xff33433c);c.drawRoundRect(r,7,7,p);p.setColor(0xffeae7d9);c.drawCircle(r.centerX(),r.centerY(),3,p);if(spin==i){p.setColor(gold);c.drawCircle(r.centerX(),r.centerY(),6,p);}}
            float cy=gy+3*(cell+5)+12; text(c,"球杆角度",x+16,cy+fs,fs,ivory,true); angleMinus.set(x+w-88,cy,x+w-54,cy+30);anglePlus.set(x+w-42,cy,x+w-8,cy+30);smallButton(c,angleMinus,"−");smallButton(c,anglePlus,"+"); text(c,Math.round(angle)+"°",x+w*.50f,cy+21,fs,gold,true);
            cy+=50;text(c,"击球力度",x+16,cy+fs,fs,ivory,true);powerMinus.set(x+w-88,cy,x+w-54,cy+30);powerPlus.set(x+w-42,cy,x+w-8,cy+30);smallButton(c,powerMinus,"−");smallButton(c,powerPlus,"+");
            float barX=x+16,barY=cy+fs+17,barW=w-32;p.setColor(0xff405149);c.drawRoundRect(barX,barY,barX+barW,barY+6,4,4,p);p.setColor(0xff68d3ad);c.drawRoundRect(barX,barY,barX+barW*power,barY+6,4,4,p);p.setColor(ivory);c.drawCircle(barX+barW*power,barY+3,8,p);
            float buttonsY=y+panelH-54;strike.set(x+14,buttonsY,x+w-14,buttonsY+42);p.setColor(0xff54c89b);c.drawRoundRect(strike,12,12,p);textCentered(c,"击 球",strike.centerX(),strike.centerY()+fs*.34f,fs,dark,true);
            reset.set(x+14,buttonsY-43,x+w-14,buttonsY-8);p.setColor(0xff33433c);c.drawRoundRect(reset,10,10,p);textCentered(c,"重置球型",reset.centerX(),reset.centerY()+5,12,ivory,false);
            if(!landscape){text(c,"拖动母球或目标球摆球 · 点选目标球",x+14,buttonsY-65,11,0xffaebdb6,false);}
        }
        void button(Canvas c,RectF r,String s,boolean active){p.setColor(active?0xff54c89b:0xff293631);c.drawRoundRect(r,16,16,p);textCentered(c,s,r.centerX(),r.centerY()+6,14,active?dark:ivory,true);}
        void smallButton(Canvas c,RectF r,String s){p.setColor(0xff35453e);c.drawRoundRect(r,7,7,p);textCentered(c,s,r.centerX(),r.centerY()+6,18,ivory,true);}
        void text(Canvas c,String s,float x,float y,float size,int color,boolean bold){p.setColor(color);p.setTypeface(bold?android.graphics.Typeface.create("sans-serif",1):android.graphics.Typeface.create("sans-serif",0));p.setTextSize(size);p.setTextAlign(Paint.Align.LEFT);c.drawText(s,x,y,p);}
        void textCentered(Canvas c,String s,float x,float y,float size,int color,boolean bold){p.setColor(color);p.setTypeface(android.graphics.Typeface.create("sans-serif",bold?1:0));p.setTextSize(size);p.setTextAlign(Paint.Align.CENTER);c.drawText(s,x,y,p);p.setTextAlign(Paint.Align.LEFT);}
        @Override public boolean onTouchEvent(MotionEvent e){float x=e.getX(),y=e.getY();
            if(e.getAction()==MotionEvent.ACTION_DOWN){downX=x;downY=y; if(in(x,y,strike)||in(x,y,reset)||in(x,y,modeFree)||in(x,y,modeAr)||in(x,y,updateButton)||in(x,y,angleMinus)||in(x,y,anglePlus)||in(x,y,powerMinus)||in(x,y,powerPlus)){return true;}
                if(x>=tx&&x<=tx+tw&&y>=ty&&y<=ty+th){int hit=-1;for(int i=0;i<balls.size();i++){Ball b=balls.get(i);float px=tx+b.x*tw,py=ty+b.y*th;if(Math.hypot(x-px,y-py)<Math.min(tw,th)*.055f)hit=i;}
                    if(hit>=0){if(hit>0)selected=hit;dragging=true;} else {Ball b=balls.get(0);b.x=clamp((x-tx)/tw,.03f,.97f);b.y=clamp((y-ty)/th,.04f,.96f);} invalidate();return true;}
                for(int i=0;i<9;i++)if(in(x,y,spinCells[i])){spin=i;invalidate();return true;}
                if(y>panelY&&y<panelY+panelH&&x>=panelX){float barY=powerBarY();if(y>barY-12&&y<barY+20){power=clamp((x-(panelX+16))/(panelW-32),0,1);powerDragging=true;invalidate();return true;}}
                return true;}
            if(e.getAction()==MotionEvent.ACTION_MOVE&&powerDragging){power=clamp((x-(panelX+16))/(panelW-32),0,1);invalidate();return true;}
            if(e.getAction()==MotionEvent.ACTION_MOVE&&dragging){Ball b=balls.get(selected);b.x=clamp((x-tx)/tw,.025f,.975f);b.y=clamp((y-ty)/th,.04f,.96f);invalidate();return true;}
            if(e.getAction()==MotionEvent.ACTION_UP){if(powerDragging){powerDragging=false;return true;}if(dragging){dragging=false;return true;} if(in(x,y,modeFree)){ar=false;invalidate();return true;}if(in(x,y,modeAr)){ar=true;invalidate();return true;}if(in(x,y,updateButton)){((MainActivity)getContext()).checkForUpdates();return true;}if(in(x,y,angleMinus)){angle=Math.max(0,angle-5);invalidate();return true;}if(in(x,y,anglePlus)){angle=Math.min(90,angle+5);invalidate();return true;}if(in(x,y,powerMinus)){power=Math.max(0,power-.1f);invalidate();return true;}if(in(x,y,powerPlus)){power=Math.min(1,power+.1f);invalidate();return true;}if(in(x,y,reset)){initBalls();return true;}if(in(x,y,strike)){shoot();invalidate();return true;}return true;}return true;
        }
        float powerBarY(){float fs=Math.max(12,Math.min(16,panelW*.065f)),cell=Math.min(34,panelW*.14f);return panelY+18+fs+13+3*(cell+5)+12+50+fs+17;}
        void shoot(){Ball cue=balls.get(0),obj=balls.get(selected);float dx=obj.x-cue.x,dy=obj.y-cue.y,l=(float)Math.hypot(dx,dy);if(l<.001)return;dx/=l;dy/=l;float travel=Math.min(.45f,.08f+power*.5f);cue.x=clamp(obj.x-dx*.045f,.025f,.975f);cue.y=clamp(obj.y-dy*.045f,.04f,.96f);obj.x=clamp(obj.x+dx*travel,.025f,.975f);obj.y=clamp(obj.y+dy*travel,.04f,.96f);}
        boolean in(float x,float y,RectF r){return r.contains(x,y);}float clamp(float v,float a,float b){return Math.max(a,Math.min(b,v));}
    }
}

