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

    void showSettings() {
        new AlertDialog.Builder(this).setTitle("设置")
                .setItems(new String[]{"使用帮助", "检查更新"}, (dialog, which) -> {
                    if (which == 0) showHelp();
                    else checkForUpdates();
                }).setNegativeButton("关闭", null).show();
    }

    private void showHelp() {
        new AlertDialog.Builder(this).setTitle("练习帮助")
                .setMessage("• 拖动球台上的母球和目标球摆球；轻点目标球可选中。\n\n• 在底部白球上拖动红点，设置母球击点。\n\n• 拖动角度和力度滑杆，点击“击球”预览效果。\n\n• AR 识别功能仍在开发中。")
                .setPositiveButton("知道了", null).show();
    }

    static class Ball { float x,y; int color; String label; Ball(float x,float y,int c,String l){this.x=x;this.y=y;color=c;label=l;} }

    static class TableView extends View {
        final Paint p=new Paint(Paint.ANTI_ALIAS_FLAG);
        final ArrayList<Ball> balls=new ArrayList<>();
        final int felt=0xff176f4b, rail=0xff5a3824, gold=0xffffc86f, ivory=0xfff7f2e2, dark=0xff111916;
        int selected=1; float spinX=0,spinY=0,angle=0,power=.55f;
        float W,H,s,tx,ty,tw,th,barY,barH,ballCX,ballCY,ballR,angleL,angleR,powerL,powerR;
        boolean ar=false,ballDrag=false,angleDrag=false,powerDrag=false,spinDrag=false;
        RectF modeFree=new RectF(),modeAr=new RectF(),settings=new RectF(),strike=new RectF(),reset=new RectF(),spinZone=new RectF();
        TableView(Activity a){super(a);setLayerType(View.LAYER_TYPE_SOFTWARE,null);initBalls();}
        void initBalls(){balls.clear();balls.add(new Ball(.26f,.52f,0xfff8f5e9,"母"));int[] colors={0xffe8bd38,0xff3987ca,0xffd74e48,0xff7952a1,0xffe68a36,0xff3c9765,0xff9a4656,0xff171717};String[] labels={"1","2","3","4","5","6","7","8"};float[][] pos={{.69f,.50f},{.73f,.45f},{.73f,.55f},{.77f,.40f},{.77f,.50f},{.77f,.60f},{.81f,.45f},{.81f,.55f}};for(int i=0;i<8;i++)balls.add(new Ball(pos[i][0],pos[i][1],colors[i],labels[i]));selected=1;invalidate();}

        @Override protected void onDraw(Canvas c){super.onDraw(c);W=getWidth();H=getHeight();s=Math.max(.68f,Math.min(W/900f,H/400f));c.drawColor(dark);
            float header=43*s;barH=108*s;barY=H-barH;
            p.setColor(0xff18231e);c.drawRect(0,0,W,header,p);text(c,"中八解球",18*s,28*s,20*s,ivory,true);
            modeFree.set(W-210*s,7*s,W-143*s,38*s);modeAr.set(W-135*s,7*s,W-78*s,38*s);settings.set(W-69*s,7*s,W-12*s,38*s);
            button(c,modeFree,"自由练习",!ar,s);button(c,modeAr,"AR 解球",ar,s);button(c,settings,"设置",false,s);
            float availableH=barY-header-14*s;th=Math.max(90*s,Math.min(availableH,(W-40*s)/2.05f));tw=th*2.05f;tx=(W-tw)*.5f;ty=header+(availableH-th)*.5f;
            drawTable(c);drawControls(c,s);
        }

        void drawTable(Canvas c){float r=Math.max(7*s,Math.min(tw,th)*.042f);p.setColor(0xff251b15);c.drawRoundRect(tx-r*1.45f,ty-r*1.45f,tx+tw+r*1.45f,ty+th+r*1.45f,r,r,p);p.setColor(rail);c.drawRoundRect(tx-r,ty-r,tx+tw+r,ty+th+r,r,r,p);p.setColor(felt);c.drawRect(tx,ty,tx+tw,ty+th,p);
            float pocket=Math.max(7*s,th*.035f);p.setColor(0xff090e0c);float[][] holes={{tx,ty},{tx+tw/2,ty},{tx+tw,ty},{tx,ty+th},{tx+tw/2,ty+th},{tx+tw,ty+th}};for(float[] q:holes)c.drawCircle(q[0],q[1],pocket,p);
            Ball cue=balls.get(0),target=balls.get(Math.min(selected,balls.size()-1));float cx=tx+cue.x*tw,cy=ty+cue.y*th,ox=tx+target.x*tw,oy=ty+target.y*th,dx=ox-cx,dy=oy-cy,len=(float)Math.hypot(dx,dy);
            if(len>0){dx/=len;dy/=len;float br=th*.025f;dashed(c,cx,cy,ox-dx*br*1.8f,oy-dy*br*1.8f,0xfff8e9b2,2*s);float[] end=rayLimit(ox,oy,dx,dy,br);dashed(c,ox+dx*br*1.8f,oy+dy*br*1.8f,end[0],end[1],gold,2*s);}
            for(int i=0;i<balls.size();i++){Ball b=balls.get(i);float x=tx+b.x*tw,y=ty+b.y*th,br=th*.033f;p.setColor(0x55000000);c.drawCircle(x+br*.12f,y+br*.15f,br,p);p.setColor(b.color);c.drawCircle(x,y,br,p);if(i==selected){p.setColor(gold);p.setStyle(Paint.Style.STROKE);p.setStrokeWidth(2*s);c.drawCircle(x,y,br+4*s,p);p.setStyle(Paint.Style.FILL);}p.setColor(i==8?ivory:0xff17221c);p.setTextSize(br*.8f);p.setTextAlign(Paint.Align.CENTER);p.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);c.drawText(b.label,x,y+br*.28f,p);}
            if(ar){p.setColor(0xd6111916);c.drawRoundRect(tx+tw*.28f,ty+th*.35f,tx+tw*.72f,ty+th*.65f,12*s,12*s,p);textCentered(c,"AR 球台识别待接入",tx+tw/2,ty+th*.47f,16*s,ivory,true);textCentered(c,"当前可使用自由练习",tx+tw/2,ty+th*.57f,12*s,0xffc2d0c8,false);}
            p.setTextAlign(Paint.Align.LEFT);
        }
        float[] rayLimit(float x,float y,float dx,float dy,float margin){float best=Float.POSITIVE_INFINITY,bx=x,by=y;float[] xs={tx+margin,tx+tw-margin},ys={ty+margin,ty+th-margin};if(dx>0){float t=(xs[1]-x)/dx;if(t>0&&t<best){best=t;bx=xs[1];by=y+dy*t;}}else if(dx<0){float t=(xs[0]-x)/dx;if(t>0&&t<best){best=t;bx=xs[0];by=y+dy*t;}}if(dy>0){float t=(ys[1]-y)/dy;if(t>0&&t<best){best=t;bx=x+dx*t;by=ys[1];}}else if(dy<0){float t=(ys[0]-y)/dy;if(t>0&&t<best){best=t;bx=x+dx*t;by=ys[0];}}return new float[]{bx,by};}
        void dashed(Canvas c,float x1,float y1,float x2,float y2,int color,float width){float d=(float)Math.hypot(x2-x1,y2-y1);int n=Math.max(1,(int)(d/(7*s)));p.setColor(color);p.setStrokeWidth(width);for(int i=0;i<n;i+=2){float a=i/(float)n,b=Math.min(1,(i+1)/(float)n);c.drawLine(x1+(x2-x1)*a,y1+(y2-y1)*a,x1+(x2-x1)*b,y1+(y2-y1)*b,p);}}

        void drawControls(Canvas c,float scale){p.setColor(0xff202a24);c.drawRoundRect(8*scale,barY+5*scale,W-8*scale,H+18*scale,16*scale,16*scale,p);
            float cy=barY+55*scale;ballCX=68*scale;ballCY=cy;ballR=35*scale;spinZone.set(ballCX-ballR,cy-ballR,ballCX+ballR,cy+ballR);
            text(c,"母球击点",22*scale,barY+19*scale,12*scale,ivory,true);p.setColor(0xfffaf8ed);c.drawCircle(ballCX,ballCY,ballR,p);p.setColor(0xffd9ddda);p.setStyle(Paint.Style.STROKE);p.setStrokeWidth(1.4f*scale);c.drawCircle(ballCX,ballCY,ballR,p);p.setStyle(Paint.Style.FILL);p.setColor(0xffd5232b);c.drawCircle(ballCX+spinX*ballR*.66f,ballCY+spinY*ballR*.66f,5*scale,p);
            float labelY=barY+25*scale;angleL=135*scale;angleR=W*.43f;powerL=W*.48f;powerR=W-122*scale;
            text(c,"球杆角度",angleL,labelY,12*scale,ivory,true);text(c,Math.round(angle)+"°",angleR-25*scale,labelY,12*scale,gold,true);drawSlider(c,angleL,angleL+10*scale,angleR,labelY+22*scale,angle/90f,scale);
            text(c,"击球力度",powerL,labelY,12*scale,ivory,true);text(c,Math.round(power*100)+"%",powerR-36*scale,labelY,12*scale,gold,true);drawSlider(c,powerL,powerL+10*scale,powerR,labelY+22*scale,power,scale);
            reset.set(powerR-2*scale,barY+68*scale,powerR+56*scale,barY+94*scale);smallButton(c,reset,"重置",scale);
            strike.set(powerR+12*scale,barY+65*scale,W-18*scale,barY+96*scale);button(c,strike,"击 球",true,scale);
        }
        void drawSlider(Canvas c,float left,float trackL,float right,float y,float value,float scale){p.setColor(0xff42534a);c.drawRoundRect(trackL,y-3*scale,right,y+3*scale,4*scale,4*scale,p);p.setColor(0xff68d2a5);c.drawRoundRect(trackL,y-3*scale,trackL+(right-trackL)*value,y+3*scale,4*scale,4*scale,p);p.setColor(0x6643544b);c.drawCircle(trackL+(right-trackL)*value,y,12*scale,p);p.setColor(ivory);c.drawCircle(trackL+(right-trackL)*value,y,8*scale,p);}
        void button(Canvas c,RectF r,String label,boolean active,float scale){p.setColor(active?0xff69d5a8:0xff304038);c.drawRoundRect(r,10*scale,10*scale,p);textCentered(c,label,r.centerX(),r.centerY()+4*scale,11*scale,active?0xff12201a:ivory,true);}
        void smallButton(Canvas c,RectF r,String label,float scale){p.setColor(0xff33433b);c.drawRoundRect(r,8*scale,8*scale,p);textCentered(c,label,r.centerX(),r.centerY()+4*scale,11*scale,ivory,false);}
        void text(Canvas c,String v,float x,float y,float size,int color,boolean bold){p.setColor(color);p.setTypeface(android.graphics.Typeface.create("sans-serif",bold?1:0));p.setTextSize(size);p.setTextAlign(Paint.Align.LEFT);c.drawText(v,x,y,p);}
        void textCentered(Canvas c,String v,float x,float y,float size,int color,boolean bold){p.setColor(color);p.setTypeface(android.graphics.Typeface.create("sans-serif",bold?1:0));p.setTextSize(size);p.setTextAlign(Paint.Align.CENTER);c.drawText(v,x,y,p);p.setTextAlign(Paint.Align.LEFT);}

        @Override public boolean onTouchEvent(MotionEvent e){float x=e.getX(),y=e.getY();int action=e.getAction();
            if(action==MotionEvent.ACTION_DOWN){if(in(x,y,settings)||in(x,y,modeFree)||in(x,y,modeAr)||in(x,y,strike)||in(x,y,reset))return true;
                if(in(x,y,spinZone)){spinDrag=true;updateSpin(x,y);return true;}
                float labelY=barY+25*s,trackY=labelY+22*s;if(y>trackY-20*s&&y<trackY+20*s&&x>angleL&&x<angleR){angleDrag=true;updateAngle(x);return true;}if(y>trackY-20*s&&y<trackY+20*s&&x>powerL&&x<powerR){powerDrag=true;updatePower(x);return true;}
                if(x>=tx&&x<=tx+tw&&y>=ty&&y<=ty+th){int hit=-1;for(int i=0;i<balls.size();i++){Ball b=balls.get(i);if(Math.hypot(x-(tx+b.x*tw),y-(ty+b.y*th))<th*.055f)hit=i;}if(hit>=0){if(hit>0)selected=hit;ballDrag=true;}else{Ball b=balls.get(0);b.x=clamp((x-tx)/tw,.03f,.97f);b.y=clamp((y-ty)/th,.04f,.96f);}invalidate();return true;}return true;}
            if(action==MotionEvent.ACTION_MOVE){if(spinDrag)updateSpin(x,y);if(angleDrag)updateAngle(x);if(powerDrag)updatePower(x);if(ballDrag){Ball b=balls.get(selected);b.x=clamp((x-tx)/tw,.025f,.975f);b.y=clamp((y-ty)/th,.04f,.96f);}invalidate();return true;}
            if(action==MotionEvent.ACTION_UP){if(spinDrag){spinDrag=false;return true;}if(angleDrag){angleDrag=false;return true;}if(powerDrag){powerDrag=false;return true;}if(ballDrag){ballDrag=false;return true;}if(in(x,y,modeFree)){ar=false;invalidate();return true;}if(in(x,y,modeAr)){ar=true;invalidate();return true;}if(in(x,y,settings)){((MainActivity)getContext()).showSettings();return true;}if(in(x,y,reset)){initBalls();spinX=spinY=0;return true;}if(in(x,y,strike)){shoot();invalidate();return true;}return true;}return true;
        }
        void updateSpin(float x,float y){spinX=clamp((x-ballCX)/(ballR*.66f),-1,1);spinY=clamp((y-ballCY)/(ballR*.66f),-1,1);invalidate();}
        void updateAngle(float x){angle=clamp((x-(angleL+10*s))/(angleR-(angleL+10*s)),0,1)*90;invalidate();}
        void updatePower(float x){power=clamp((x-(powerL+10*s))/(powerR-(powerL+10*s)),0,1);invalidate();}
        void shoot(){Ball cue=balls.get(0),obj=balls.get(selected);float dx=obj.x-cue.x,dy=obj.y-cue.y,l=(float)Math.hypot(dx,dy);if(l<.001f)return;dx/=l;dy/=l;float travel=Math.min(.45f,.08f+power*.5f);cue.x=clamp(obj.x-dx*.045f+spinX*.012f,.025f,.975f);cue.y=clamp(obj.y-dy*.045f+spinY*.012f,.04f,.96f);obj.x=clamp(obj.x+dx*travel,.025f,.975f);obj.y=clamp(obj.y+dy*travel,.04f,.96f);}
        boolean in(float x,float y,RectF r){return r.contains(x,y);}float clamp(float v,float a,float b){return Math.max(a,Math.min(b,v));}
    }
}
