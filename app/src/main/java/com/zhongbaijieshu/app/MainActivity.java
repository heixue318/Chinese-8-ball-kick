package com.zhongbaijieshu.app;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.DownloadManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.os.Build;
import android.database.Cursor;
import android.widget.Toast;
import android.view.View;
import org.json.JSONObject;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;

public class MainActivity extends Activity {
    private static final String UPDATE_URL = "https://raw.githubusercontent.com/heixue318/Chinese-8-ball-kick/main/update.json";
    private long updateDownloadId = -1;
    private Uri pendingInstallUri;
    private boolean waitingInstallPermission;
    private BroadcastReceiver downloadReceiver;

    // The legacy overload is used only below Android 13, where flags do not exist.
    @android.annotation.SuppressLint("UnspecifiedRegisterReceiverFlag")
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_FULLSCREEN | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION);
        setContentView(new PracticeView(this));
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
                .setMessage("• 拖动台面瞄准；右侧竖向微调器可精调方向。\n\n• 左侧向下拉杆蓄力，松手击球；也可点击“击球”使用当前力度。\n\n• 点击摆球后拖动任意球调整位置，再关闭摆球。\n\n• 右侧白球设置击点，− / + 调整杆角。\n\n• 重试本杆恢复击球前球局；可选择解球球局或十五球。\n\n• 辅助线显示理想反射，旋转和物理为近似模拟，不模拟跳球。AR 尚未接入。")
                .setPositiveButton("知道了", null).show();
    }

}
