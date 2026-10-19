import os, sys, time, signal, socket, subprocess
from collections import deque

import psutil
from PySide6.QtCore import QObject, Signal, Slot, QTimer, QAbstractListModel, QModelIndex, Qt
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

APP_NAME = 'TaskGlass'


def fmt_bytes(n):
    n = float(n)
    for unit in ['B','KB','MB','GB','TB','PB']:
        if n < 1024 or unit == 'PB':
            return f'{n:.1f} {unit}'
        n /= 1024
    return f'{n:.1f} PB'


def fmt_rate(n):
    if n < 1024:
        return f'{n:.0f} B/s'
    if n < 1024**2:
        return f'{n/1024:.1f} KB/s'
    if n < 1024**3:
        return f'{n/1024**2:.1f} MB/s'
    return f'{n/1024**3:.1f} GB/s'


def safe_name(p):
    try:
        return p.info.get('name') or p.name()
    except Exception:
        return ''


class ProcessModel(QAbstractListModel):
    PID = Qt.UserRole + 1
    NAME = Qt.UserRole + 2
    USER = Qt.UserRole + 3
    CPU = Qt.UserRole + 4
    MEM = Qt.UserRole + 5
    STATE = Qt.UserRole + 6
    THREADS = Qt.UserRole + 7
    CMD = Qt.UserRole + 8
    START = Qt.UserRole + 9

    roles = {PID:'pid', NAME:'name', USER:'user', CPU:'cpu', MEM:'mem', STATE:'state', THREADS:'threads', CMD:'cmd', START:'start'}

    def __init__(self):
        super().__init__()
        self.items = []
        self.sort_key = 'cpu'
        self.desc = True

    def rowCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else len(self.items)

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid() or index.row() >= len(self.items):
            return None
        item = self.items[index.row()]
        return item.get(self.roles.get(role))

    def set_data(self, items):
        self.beginResetModel(); self.items = items; self.endResetModel()

    def item(self, row):
        return self.items[row] if 0 <= row < len(self.items) else None


class Backend(QObject):
    metricsChanged = Signal()
    clockChanged = Signal(str)
    toast = Signal(str, str)
    selectedChanged = Signal()
    processCountChanged = Signal()
    networkChanged = Signal()
    diskChanged = Signal()
    modelChanged = Signal()

    def __init__(self):
        super().__init__()
        self.model = ProcessModel()
        self.selected_pid = 0
        self.filter_text = ''
        self.sort_key = 'cpu'
        self.sort_desc = True
        self.cpu_history = deque([0]*60, maxlen=60)
        self.mem_history = deque([0]*60, maxlen=60)
        self.disk_history = deque([0]*60, maxlen=60)
        self.net_history = deque([0]*60, maxlen=60)
        self.last_net = psutil.net_io_counters()
        self.last_disk = psutil.disk_io_counters()
        self.last_t = time.monotonic()
        self.cpu = 0; self.mem = 0; self.disk = 0; self.net_down = 0; self.net_up = 0
        self.hostname = socket.gethostname()
        self.os_name = self._os_name()
        self.boot_time = psutil.boot_time()
        psutil.cpu_percent(interval=None)
        for p in psutil.process_iter(['pid','name']):
            try: p.cpu_percent(None)
            except: pass
        self.refresh()
        self.timer = QTimer(self); self.timer.timeout.connect(self.refresh); self.timer.start(1000)
        self.clock_timer = QTimer(self); self.clock_timer.timeout.connect(self._clock); self.clock_timer.start(1000)
        self._clock()

    def _os_name(self):
        try:
            with open('/etc/os-release') as f:
                data = f.read()
            for line in data.splitlines():
                if line.startswith('PRETTY_NAME='):
                    return line.split('=',1)[1].strip().strip('"')
        except: pass
        return sys.platform

    def _clock(self):
        self.clockChanged.emit(time.strftime('%a, %d %b  •  %H:%M:%S'))

    def refresh(self):
        now = time.monotonic(); dt = max(0.001, now - self.last_t); self.last_t = now
        self.cpu = psutil.cpu_percent(None)
        vm = psutil.virtual_memory(); self.mem = vm.percent
        du = psutil.disk_usage('/'); self.disk = du.percent
        net = psutil.net_io_counters(); diskio = psutil.disk_io_counters()
        self.net_down = max(0, net.bytes_recv - self.last_net.bytes_recv) / dt
        self.net_up = max(0, net.bytes_sent - self.last_net.bytes_sent) / dt
        self.last_net = net
        disk_bytes = max(0, (diskio.read_bytes + diskio.write_bytes) - (self.last_disk.read_bytes + self.last_disk.write_bytes)) / dt
        self.last_disk = diskio
        self.cpu_history.append(self.cpu); self.mem_history.append(self.mem); self.disk_history.append(self.disk); self.net_history.append((self.net_down+self.net_up)/1024)
        self.metricsChanged.emit()
        self._refresh_processes()
        self.networkChanged.emit(); self.diskChanged.emit(); self.selectedChanged.emit()

    def _refresh_processes(self):
        out=[]
        q = self.filter_text.lower().strip()
        for p in psutil.process_iter(['pid','name','username','status','num_threads','cmdline','create_time','memory_percent']):
            try:
                name = p.info.get('name') or '—'
                pid = p.info['pid']
                user = p.info.get('username') or 'system'
                cmd = ' '.join(p.info.get('cmdline') or [])
                if q and q not in f'{pid} {name} {user} {cmd}'.lower():
                    continue
                cpu = p.cpu_percent(None)
                mem = float(p.info.get('memory_percent') or 0)
                out.append({'pid':pid, 'name':name, 'user':user.split('\\')[-1].split('/')[-1], 'cpu':round(cpu,1), 'mem':round(mem,1), 'state':p.info.get('status') or '—', 'threads':p.info.get('num_threads') or 0, 'cmd':cmd, 'start':p.info.get('create_time') or 0})
            except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                continue
        key = {'cpu':'cpu','mem':'mem','pid':'pid','name':'name','user':'user'}.get(self.sort_key,'cpu')
        out.sort(key=lambda x: (x.get(key) is None, x.get(key)), reverse=self.sort_desc)
        self.model.set_data(out)
        self.modelChanged.emit(); self.processCountChanged.emit()

    @Slot(str)
    def setFilter(self, text):
        self.filter_text = text
        self._refresh_processes()

    @Slot(str)
    def sortBy(self, key):
        if key == self.sort_key: self.sort_desc = not self.sort_desc
        else: self.sort_key, self.sort_desc = key, True
        self._refresh_processes()

    @Slot(int)
    def selectProcess(self, pid):
        self.selected_pid = int(pid)
        self.selectedChanged.emit()

    @Slot(int)
    def terminate(self, pid):
        try:
            p=psutil.Process(int(pid)); p.terminate(); self.toast.emit(f'Sent SIGTERM to {pid}', 'good')
        except Exception as e: self.toast.emit(f'Could not terminate {pid}: {e}', 'bad')
        QTimer.singleShot(600, self._refresh_processes)

    @Slot(int)
    def kill(self, pid):
        try:
            p=psutil.Process(int(pid)); p.kill(); self.toast.emit(f'Force killed {pid}', 'warn')
        except Exception as e: self.toast.emit(f'Kill failed: {e}', 'bad')
        QTimer.singleShot(600, self._refresh_processes)

    @Slot(int)
    def suspend(self, pid):
        try:
            psutil.Process(int(pid)).suspend(); self.toast.emit(f'Suspended {pid}', 'warn')
        except Exception as e: self.toast.emit(f'Suspend failed: {e}', 'bad')
        QTimer.singleShot(500, self._refresh_processes)

    @Slot(int)
    def resume(self, pid):
        try:
            psutil.Process(int(pid)).resume(); self.toast.emit(f'Resumed {pid}', 'good')
        except Exception as e: self.toast.emit(f'Resume failed: {e}', 'bad')
        QTimer.singleShot(500, self._refresh_processes)

    @Slot(str)
    def launch(self, command):
        try:
            subprocess.Popen(command, shell=True, start_new_session=True)
            self.toast.emit(f'Launched: {command}', 'good')
        except Exception as e: self.toast.emit(f'Launch failed: {e}', 'bad')

    @Slot()
    def openSystemMonitor(self):
        for cmd in [['gnome-system-monitor'], ['ksysguard'], ['xfce4-taskmanager']]:
            try:
                subprocess.Popen(cmd); self.toast.emit('Opened system monitor', 'good'); return
            except: pass
        self.toast.emit('No desktop system monitor found', 'warn')

    def _selected(self):
        pid=self.selected_pid
        if not pid: return None
        try:
            p=psutil.Process(pid)
            mem=p.memory_info(); io=None
            try: io=p.io_counters()
            except: pass
            return {
                'pid':pid,'name':p.name(),'exe':p.exe() if p.exe() else '—','user':p.username(),'cpu':p.cpu_percent(None),
                'mem':p.memory_percent(),'rss':mem.rss,'threads':p.num_threads(),'status':p.status(),'cwd':p.cwd() if p.cwd() else '—',
                'cmd':' '.join(p.cmdline()),'nice':p.nice(),'open_files':len(p.open_files()),'connections':len(p.net_connections()),
                'read':getattr(io,'read_bytes',0) if io else 0,'write':getattr(io,'write_bytes',0) if io else 0,
            }
        except: return None

    # QML properties
    def val(self, key):
        if key == 'cpu': return self.cpu
        if key == 'memUsed': return fmt_bytes(psutil.virtual_memory().used) + ' / ' + fmt_bytes(psutil.virtual_memory().total)
        if key == 'mem': return self.mem
        if key == 'disk': return self.disk
        if key == 'down': return self.net_down
        if key == 'up': return self.net_up
        if key == 'cpuHist': return list(self.cpu_history)
        if key == 'memHist': return list(self.mem_history)
        if key == 'diskHist': return list(self.disk_history)
        if key == 'netHist': return list(self.net_history)
        if key == 'processCount': return len(self.model.items)
        if key == 'hostname': return self.hostname
        if key == 'os': return self.os_name
        if key == 'cores': return psutil.cpu_count(logical=False) or psutil.cpu_count() or 1
        if key == 'threads': return psutil.cpu_count(logical=True) or 1
        if key == 'uptime': return self._uptime()
        if key == 'load': return ' / '.join(f'{x:.2f}' for x in os.getloadavg()) if hasattr(os,'getloadavg') else '—'
        if key == 'swap': return psutil.swap_memory().percent
        if key == 'rootFree': return fmt_bytes(psutil.disk_usage('/').free)
        if key == 'downFmt': return fmt_rate(self.net_down)
        if key == 'upFmt': return fmt_rate(self.net_up)
        if key == 'selected': return self._selected() or {}
        return ''

    def _uptime(self):
        secs=max(0,int(time.time()-self.boot_time)); d,rem=divmod(secs,86400); h,rem=divmod(rem,3600); m,_=divmod(rem,60)
        return f'{d}d {h}h {m}m'

    @Slot(result='QVariant')
    def stats(self): return self._stats_dict()

    def _stats_dict(self):
        vm=psutil.virtual_memory(); sw=psutil.swap_memory(); du=psutil.disk_usage('/'); ni=psutil.net_if_addrs()
        conns=[]
        try:
            for c in psutil.net_connections(kind='inet')[:120]:
                l = f'{c.laddr.ip}:{c.laddr.port}' if c.laddr else '—'; r=f'{c.raddr.ip}:{c.raddr.port}' if c.raddr else '—';
                conns.append({'fd':c.fd,'type':str(c.type),'local':l,'remote':r,'status':c.status,'pid':c.pid or 0})
        except: pass
        disks=[]
        for p in psutil.disk_partitions(all=False):
            try:
                u=psutil.disk_usage(p.mountpoint); disks.append({'mount':p.mountpoint,'device':p.device,'fstype':p.fstype,'used':u.percent,'free':fmt_bytes(u.free),'total':fmt_bytes(u.total)})
            except: pass
        return {'memTotal':fmt_bytes(vm.total),'memUsed':fmt_bytes(vm.used),'swap':sw.percent,'rootFree':fmt_bytes(du.free),'interfaces':list(ni.keys()),'connections':conns,'disks':disks}

    @Slot(result='QString')
    def selectedJson(self):
        import json; return json.dumps(self._selected() or {})

    @Slot(result='QString')
    def statsJson(self):
        import json; return json.dumps(self._stats_dict())


app = QGuiApplication(sys.argv)
app.setApplicationName(APP_NAME)
engine = QQmlApplicationEngine()
backend = Backend()
engine.rootContext().setContextProperty('backend', backend)
engine.rootContext().setContextProperty('processModel', backend.model)
qml = os.path.join(os.path.dirname(__file__), 'ui', 'Main.qml')
engine.load(qml)
if not engine.rootObjects():
    sys.exit(2)
sys.exit(app.exec())
