"""ADB smoke test; coordinates derive from accessibility/UI-tree bounds."""
import pathlib, re, subprocess, sys, time, xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADB = ROOT / '.tools/android/platform-tools/adb.exe'
OUT = ROOT / '.tools/qa'
OUT.mkdir(parents=True, exist_ok=True)

def adb(*args):
    return subprocess.check_output([str(ADB), '-s', 'emulator-5554', *map(str,args)], text=True, encoding='utf-8', errors='replace')

def state(name):
    adb('shell','uiautomator','dump','/sdcard/practice-ui.xml')
    path = OUT / (name + '.xml')
    adb('pull','/sdcard/practice-ui.xml',path)
    return ET.parse(path).getroot()

def node(tree, desc):
    return next(n for n in tree.iter('node') if n.get('content-desc') == desc)

def box(n):
    return list(map(int,re.findall(r'\d+', n.get('bounds'))))

def center(n):
    a,b,c,d=box(n)
    return (a+c)//2,(b+d)//2

def tap(tree,desc):
    adb('shell','input','tap',*center(node(tree,desc)))

def ball_positions(tree):
    return {n.get('content-desc'):center(n) for n in tree.iter('node') if n.get('content-desc','').startswith(('母球','目标球')) and n.get('content-desc')!='母球击点'}

def near(a,b):
    return abs(a[0]-b[0])<=2 and abs(a[1]-b[1])<=2

def screenshot(name):
    adb('shell','screencap','-p','/sdcard/practice.png')
    adb('pull','/sdcard/practice.png',OUT/(name+'.png'))

adb('shell','am','force-stop','com.zhongbaijieshu.app')
adb('shell','am','start','-n','com.zhongbaijieshu.app/.MainActivity')
initial=state('01-initial')
screenshot('01-initial')
original=ball_positions(initial)
assert len(original)==3, original
tap(initial,'摆球')
editing=state('02-editing')
x,y=original['母球']
l,t,r,b=box(node(editing,'球台瞄准区域'))
adb('shell','input','swipe',x,y,x+int((r-l)*.08),y+int((b-t)*.17),500)
moved=state('03-moved')
positions=ball_positions(moved)
assert not near(positions['母球'],original['母球']), 'cue did not move'
assert all(near(positions[k],original[k]) for k in original if k!='母球'), 'object moved while dragging cue'
screenshot('03-moved')
tap(moved,'摆球')
aim=state('04-aim')
adb('shell','input','tap',*center(node(aim,'目标球 8')))
aim=state('05-aimed')
saved=ball_positions(aim)
power_node=next(n for n in aim.iter('node') if n.get('content-desc','').startswith('拉杆力度'))
l,t,r,b=box(power_node)
x=(l+r)//2
adb('shell','input','swipe',x,t+int((b-t)*.1),x,t+int((b-t)*.55),700)
tap(aim,'重试本杆')
in_motion=state('06-shot-retried')
assert any(n.get('content-desc')=='已恢复出杆前球局' for n in in_motion.iter('node')), 'drag release did not shoot or immediate retry failed'
screenshot('06-shot-retried')
restored=state('07-retry')
assert all(near(saved[k],ball_positions(restored)[k]) for k in saved), 'retry differs from pre-shot layout'
tap(restored,'十五球')
rack=state('08-rack')
assert len(ball_positions(rack))==16, 'full rack missing balls'
screenshot('08-rack')
tap(rack,'击球')
deadline=time.monotonic()+25
while True:
    finished=state('09-break')
    moving=any(n.get('content-desc')=='球体运动中…' for n in finished.iter('node'))
    if not moving: break
    assert time.monotonic()<deadline, 'break did not finish'
screenshot('09-break')
tap(finished,'重试本杆')
rack_restored=state('10-rack-retry')
assert len(ball_positions(rack_restored))==16
assert all(near(ball_positions(rack)[k],ball_positions(rack_restored)[k]) for k in ball_positions(rack))
tap(rack_restored,'解球球局')
free=state('11-free')
tap(free,'辅助线')
no_guides=state('12-no-guides')
screenshot('12-no-guides')
tap(no_guides,'辅助线')
with_guides=state('13-with-guides')
fine=node(with_guides,'拖动微调瞄准')
l,t,r,b=box(fine)
adb('shell','input','swipe',(l+r)//2,(t+b)//2,(l+r)//2,(t+b)//2+int((b-t)*.2),500)
fine_aimed=state('14-fine-aim')
screenshot('14-fine-aim')
tap(fine_aimed,'设置')
settings=state('15-settings')
help_node=next(n for n in settings.iter('node') if n.get('text')=='使用帮助')
adb('shell','input','tap',*center(help_node))
help_tree=state('16-help')
assert any(n.get('text')=='练习帮助' for n in help_tree.iter('node'))
adb('shell','input','keyevent','4')
final=state('17-final')
screenshot('17-final')
crashes=adb('logcat','-b','crash','-d')
assert 'com.zhongbaijieshu.app' not in crashes, crashes
print('PASS: launch, cue placement, aim, drag-to-shoot, retry during motion, full rack, break/rest, retry, guides, fine aim, help, no crash')
