#include "sysmon.hpp"

#include <algorithm>
#include <cerrno>
#include <cstring>
#include <dirent.h>
#include <fcntl.h>
#include <liburing.h>
#include <signal.h>
#include <unistd.h>

#include <QDir>
#include <QFile>
#include <QRegularExpression>

QString SysmonProvider::sysfsRead(const QString& path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    return QString::fromUtf8(f.readAll()).trimmed();
}

qint64 SysmonProvider::sysfsInt(const QString& path)
{
    bool ok;
    qint64 v = sysfsRead(path).toLongLong(&ok);
    return ok ? v : 0;
}

SysmonProvider::SysmonProvider(QObject* parent) : QObject(parent)
{
    m_procRingReady = (::io_uring_queue_init(2048, &m_procRing, 0) >= 0);
    discover();
    connect(&m_timer, &QTimer::timeout, this, &SysmonProvider::poll);
    m_timer.setInterval(1500);
    m_timer.start();
    poll();
}

SysmonProvider::~SysmonProvider()
{
    if (m_procRingReady)
        ::io_uring_queue_exit(&m_procRing);
}

void SysmonProvider::setInterval(int ms)
{
    if (m_timer.interval() == ms)
        return;
    m_timer.setInterval(ms);
    emit intervalChanged();
}

void SysmonProvider::discover()
{
    m_pageSize = sysconf(_SC_PAGE_SIZE);
    if (m_pageSize <= 0)
        m_pageSize = 4096;

    // Identify k10temp and amdgpu hwmon instances
    QDir hwmonDir("/sys/class/hwmon");
    QStringList entries = hwmonDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    entries.sort();
    for (const QString& e : entries)
    {
        const QString base = "/sys/class/hwmon/" + e;
        const QString name = sysfsRead(base + "/name");
        if (name == "k10temp")
            m_k10tempPath = base + "/temp1_input";
        else if (name == "amdgpu")
            m_amdgpuHwmons.append(base);
    }

    // Find amdgpu DRM cards; match to hwmons by enumeration order
    QDir drmDir("/sys/class/drm");
    QStringList cards = drmDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    cards.sort();
    static const QRegularExpression cardRe("^card\\d+$");
    static const QRegularExpression slotRe("PCI_SLOT_NAME=([^\n]+)");
    int gpuIdx = 0;
    for (const QString& card : cards)
    {
        if (!cardRe.match(card).hasMatch())
            continue;
        const QString base = "/sys/class/drm/" + card + "/device";
        const QString uevent = sysfsRead(base + "/uevent");
        if (!uevent.contains("DRIVER=amdgpu"))
            continue;

        auto m = slotRe.match(uevent);
        QString slot = m.hasMatch() ? m.captured(1).trimmed() : QString();
        bool ok;
        int busNum = slot.split(":").value(1, "00").toInt(&ok, 16);
        QString name = (ok && busNum > 0x80) ? "iGPU" : "dGPU";

        GpuEntry gpu;
        gpu.card = card;
        gpu.hwmon = gpuIdx < m_amdgpuHwmons.size() ? m_amdgpuHwmons[gpuIdx] : QString();
        gpu.name = name;
        m_gpuEntries.append(gpu);
        gpuIdx++;
    }

    // Enumerate per-core cpufreq paths
    QDir cpuDir("/sys/devices/system/cpu");
    static const QRegularExpression cpuRe("^cpu\\d+$");
    for (const QString& e : cpuDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot))
    {
        if (!cpuRe.match(e).hasMatch())
            continue;
        const QString p = "/sys/devices/system/cpu/" + e + "/cpufreq/scaling_cur_freq";
        if (QFile::exists(p))
            m_cpuFreqPaths.append(p);
    }

    // Find first battery
    QDir psDir("/sys/class/power_supply");
    for (const QString& ps : psDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot))
    {
        if (!ps.startsWith("BAT"))
            continue;
        m_battCapPath = "/sys/class/power_supply/" + ps + "/capacity";
        m_battStatusPath = "/sys/class/power_supply/" + ps + "/status";
        break;
    }
}

void SysmonProvider::setProcsActive(bool a)
{
    if (a == m_procsActive)
        return;
    m_procsActive = a;
    if (a)
    {
        m_procPollCounter = 0;
        pollProcs();
    }
    emit procsActiveChanged();
}

void SysmonProvider::poll()
{
    pollCpu();
    pollMem();
    pollGpus();
    pollBatt();
    if (m_procsActive && ++m_procPollCounter >= 2)
    {
        m_procPollCounter = 0;
        pollProcs();
    }
}

void SysmonProvider::pollCpu()
{
    QFile f("/proc/stat");
    if (!f.open(QIODevice::ReadOnly))
        return;
    const QStringList lines = QString::fromUtf8(f.readAll()).split('\n');

    QVector<CpuState> newPrevCores = m_prevCores;
    QVariantList newCores;
    bool anyCores = false;

    for (const QString& line : lines)
    {
        if (!line.startsWith("cpu"))
            break;

        const QStringList p = line.split(' ', Qt::SkipEmptyParts);
        if (p.size() < 5)
            continue;
        const bool isAgg = (p[0] == "cpu");
        const int ci = isAgg ? -1 : p[0].mid(3).toInt();

        const qint64 idle = p[4].toLongLong() + (p.size() > 5 ? p[5].toLongLong() : 0); // idle+iowait
        qint64 total = 0;
        for (int i = 1; i < p.size(); ++i)
            total += p[i].toLongLong();

        if (isAgg)
        {
            const qint64 dIdle = idle - m_prevTotal.idle;
            const qint64 dTotal = total - m_prevTotal.total;
            m_cpuTotal = dTotal > 0 ? (1.0 - double(dIdle) / dTotal) * 100.0 : 0.0;
            m_prevTotal = {idle, total};
            m_totalTicksSinceLastProc += dTotal;
        }
        else
        {
            if (ci >= newPrevCores.size())
                newPrevCores.resize(ci + 1);
            while (newCores.size() <= ci)
                newCores.append(0.0);
            const qint64 dIdle = idle - newPrevCores[ci].idle;
            const qint64 dTotal = total - newPrevCores[ci].total;
            newCores[ci] = dTotal > 0 ? (1.0 - double(dIdle) / dTotal) * 100.0 : 0.0;
            newPrevCores[ci] = {idle, total};
            anyCores = true;
        }
    }

    m_prevCores = newPrevCores;
    if (anyCores)
        m_cpuCores = newCores;

    if (!m_k10tempPath.isEmpty())
        m_cpuTemp = sysfsInt(m_k10tempPath) / 1000.0;

    if (!m_cpuFreqPaths.isEmpty())
    {
        qint64 sum = 0;
        for (const QString& p : m_cpuFreqPaths)
            sum += sysfsInt(p);
        m_cpuFreq = int(sum / m_cpuFreqPaths.size() / 1000); // kHz → MHz
    }

    emit cpuUpdated();
}

void SysmonProvider::pollMem()
{
    QFile f("/proc/meminfo");
    if (!f.open(QIODevice::ReadOnly))
        return;
    const QString content = QString::fromUtf8(f.readAll());

    QHash<QString, qint64> vals;
    static const QRegularExpression re("^(\\w+):\\s+(\\d+)", QRegularExpression::MultilineOption);
    auto it = re.globalMatch(content);
    while (it.hasNext())
    {
        const auto m = it.next();
        vals[m.captured(1)] = m.captured(2).toLongLong();
    }

    constexpr double toGiB = 1.0 / (1024.0 * 1024.0);
    const qint64 total = vals.value("MemTotal");
    m_memTotalKiB = total;
    const qint64 free_ = vals.value("MemFree");
    const qint64 bufs = vals.value("Buffers");
    const qint64 cached = vals.value("Cached");
    const qint64 srecl = vals.value("SReclaimable");
    const qint64 swapT = vals.value("SwapTotal");
    const qint64 swapF = vals.value("SwapFree");

    m_memTotal = total * toGiB;
    m_memFree = free_ * toGiB;
    m_memCached = (bufs + cached + srecl) * toGiB;
    m_memUsed = (total - free_ - bufs - cached - srecl) * toGiB;
    m_swapTotal = swapT * toGiB;
    m_swapUsed = (swapT - swapF) * toGiB;

    emit memUpdated();
}

void SysmonProvider::pollGpus()
{
    m_gpus.clear();
    for (GpuEntry& gpu : m_gpuEntries)
    {
        const QString cardBase = "/sys/class/drm/" + gpu.card + "/device";
        gpu.active = (sysfsRead(cardBase + "/power/runtime_status") == "active");

        if (gpu.active)
        {
            gpu.busy = int(sysfsInt(cardBase + "/gpu_busy_percent"));
            gpu.vramUsed = sysfsInt(cardBase + "/mem_info_vram_used");
            gpu.vramTotal = sysfsInt(cardBase + "/mem_info_vram_total");
            if (gpu.vramTotal == 0)
                gpu.vramTotal = 1;

            if (!gpu.hwmon.isEmpty())
            {
                gpu.power = int(sysfsInt(gpu.hwmon + "/power1_average") / 1000); // µW → mW
                gpu.temp = int(sysfsInt(gpu.hwmon + "/temp1_input") / 1000);     // m°C → °C
                gpu.freq = int(sysfsInt(gpu.hwmon + "/freq1_input") / 1000000);  // Hz → MHz
            }
        }

        QVariantMap m;
        m["name"] = gpu.name;
        m["card"] = gpu.card;
        m["busy"] = gpu.busy;
        m["vramUsed"] = gpu.vramUsed;
        m["vramTotal"] = gpu.vramTotal;
        m["power"] = gpu.power; // mW
        m["temp"] = gpu.temp;   // °C
        m["freq"] = gpu.freq;   // MHz
        m["active"] = gpu.active;
        m_gpus.append(m);
    }
    emit gpusUpdated();
}

void SysmonProvider::pollBatt()
{
    if (m_battCapPath.isEmpty())
    {
        if (m_battPct != -1.0)
        {
            m_battPct = -1;
            emit battUpdated();
        }
        return;
    }
    bool ok;
    m_battPct = sysfsRead(m_battCapPath).toDouble(&ok);
    if (!ok)
        m_battPct = -1;
    m_battStatus = sysfsRead(m_battStatusPath);
    m_battCharging = (m_battStatus == "Charging" || m_battStatus == "Full");
    emit battUpdated();
}

bool SysmonProvider::killProcess(int pid, int sig) { return ::kill(pid_t(pid), sig) == 0; }

// Parse a decimal integer from p, advance p past it. Returns 0 on failure.
static inline long long scanLL(const char*& p)
{
    while (*p == ' ')
        ++p;
    char* end;
    long long v = std::strtoll(p, &end, 10);
    p = end;
    return v;
}

// Skip n whitespace-separated tokens from p.
static inline void skipTokens(const char*& p, int n)
{
    for (int i = 0; i < n; ++i)
    {
        while (*p == ' ')
            ++p;
        while (*p && *p != ' ')
            ++p;
    }
}

void SysmonProvider::pollProcs()
{
    const int numCores = std::max(1, (int)m_prevCores.size());
    const double tickScale = (m_totalTicksSinceLastProc > 0) ? 100.0 * numCores / (double)m_totalTicksSinceLastProc : 0.0;
    const double memScale = (m_memTotalKiB > 0) ? (double)m_pageSize / ((double)m_memTotalKiB * 1024.0) * 100.0 : 0.0;
    m_totalTicksSinceLastProc = 0;

    // Per-entry read buffer; 384 bytes is ample for any /proc/<pid>/stat line.
    struct ProcEntry
    {
        int pid;
        char statPath[32];
        int fd;
        char buf[384];
        ssize_t nread;
    };

    QVector<ProcEntry> entries;
    entries.reserve(512);

    // Phase 0: enumerate /proc PIDs (readdir only, no file I/O yet).
    DIR* procDir = ::opendir("/proc");
    if (!procDir)
        return;
    struct dirent* de;
    while ((de = ::readdir(procDir)) != nullptr)
    {
        const char* nm = de->d_name;
        if (*nm < '1' || *nm > '9')
            continue;
        int pid = 0;
        for (const char* c = nm; *c; ++c)
        {
            if (*c < '0' || *c > '9')
            {
                pid = -1;
                break;
            }
            pid = pid * 10 + (*c - '0');
        }
        if (pid <= 0)
            continue;
        ProcEntry e;
        e.pid = pid;
        e.fd = -1;
        e.nread = 0;
        int len = std::snprintf(e.statPath, sizeof(e.statPath), "/proc/%d/stat", pid);
        if (len <= 0 || len >= (int)sizeof(e.statPath))
            continue;
        entries.push_back(e);
    }
    ::closedir(procDir);

    const int N = (int)entries.size();
    if (N == 0)
        return;

    QHash<int, ProcTick> newTicks;

    if (m_procRingReady)
    {
        // ── io_uring path: process in chunks of 2048 (ring capacity) ─────────
        // Each chunk: submit opens → wait → submit reads → wait → fire closes.
        // For typical process counts (~300) this is one chunk = ~5 roundtrips
        // instead of 3×N individual syscalls.
        constexpr int CHUNK = 2048;

        for (int base = 0; base < N; base += CHUNK)
        {
            const int end = std::min(base + CHUNK, N);
            const int chunkN = end - base;

            // Opens
            for (int i = base; i < end; i++)
            {
                struct io_uring_sqe* sqe = ::io_uring_get_sqe(&m_procRing);
                ::io_uring_prep_openat(sqe, AT_FDCWD, entries[i].statPath, O_RDONLY | O_CLOEXEC, 0);
                ::io_uring_sqe_set_data64(sqe, (uint64_t)i);
            }
            ::io_uring_submit_and_wait(&m_procRing, chunkN);
            {
                unsigned head;
                struct io_uring_cqe* cqe;
                int cnt = 0;
                io_uring_for_each_cqe(&m_procRing, head, cqe)
                {
                    entries[(int)::io_uring_cqe_get_data64(cqe)].fd = cqe->res;
                    cnt++;
                }
                ::io_uring_cq_advance(&m_procRing, cnt);
            }

            // Reads
            int readCnt = 0;
            for (int i = base; i < end; i++)
            {
                if (entries[i].fd < 0)
                    continue;
                struct io_uring_sqe* sqe = ::io_uring_get_sqe(&m_procRing);
                ::io_uring_prep_read(sqe, entries[i].fd, entries[i].buf, sizeof(entries[i].buf) - 1, 0);
                ::io_uring_sqe_set_data64(sqe, (uint64_t)i);
                readCnt++;
            }
            if (readCnt > 0)
            {
                ::io_uring_submit_and_wait(&m_procRing, readCnt);
                unsigned head;
                struct io_uring_cqe* cqe;
                int cnt = 0;
                io_uring_for_each_cqe(&m_procRing, head, cqe)
                {
                    int i = (int)::io_uring_cqe_get_data64(cqe);
                    ssize_t n = cqe->res;
                    entries[i].nread = (n > 0) ? n : 0;
                    if (n > 0)
                        entries[i].buf[n] = '\0';
                    cnt++;
                }
                ::io_uring_cq_advance(&m_procRing, cnt);
            }

            // Closes (fire-and-forget; IOSQE_CQE_SKIP_SUCCESS suppresses CQEs)
            for (int i = base; i < end; i++)
            {
                if (entries[i].fd < 0)
                    continue;
                struct io_uring_sqe* sqe = ::io_uring_get_sqe(&m_procRing);
                ::io_uring_prep_close(sqe, entries[i].fd);
                sqe->flags |= IOSQE_CQE_SKIP_SUCCESS;
            }
            ::io_uring_submit(&m_procRing);
        }
    }
    else
    {
        for (auto& e : entries)
        {
            int fd = ::open(e.statPath, O_RDONLY | O_CLOEXEC);
            if (fd < 0)
                continue;
            ssize_t n = ::read(fd, e.buf, sizeof(e.buf) - 1);
            ::close(fd);
            if (n > 0)
            {
                e.nread = n;
                e.buf[n] = '\0';
            }
        }
    }

    // Phase 4: parse all buffers.
    struct ProcInfo
    {
        int pid;
        QString name;
        char state;
        double cpu, memPct;
        qint64 memKib, virtKib;
        int threads;
    };
    QVector<ProcInfo> procs;
    procs.reserve(N);

    for (const auto& e : entries)
    {
        if (e.nread <= 0)
            continue;
        const char* buf = e.buf;

        const char* comStart = std::strchr(buf, '(');
        const char* comEnd = std::strrchr(buf, ')');
        if (!comStart || !comEnd || comEnd <= comStart)
            continue;

        const QString name = QString::fromUtf8(comStart + 1, int(comEnd - comStart - 1));

        const char* p = comEnd + 1;
        while (*p == ' ')
            ++p;
        const char state = *p ? *p : '?';
        while (*p && *p != ' ')
            ++p;

        skipTokens(p, 10);
        const long long utime = scanLL(p);
        const long long stime = scanLL(p);
        skipTokens(p, 4);
        const long long threads = scanLL(p);
        skipTokens(p, 2);
        const long long vsize = scanLL(p);
        const long long rss = scanLL(p);

        const qint64 ticks = utime + stime;
        const bool known = m_prevProcTicks.contains(e.pid);
        const qint64 prev = known ? m_prevProcTicks.value(e.pid).ticks : ticks;
        newTicks[e.pid] = {ticks};

        const double cpu = known ? std::max(0.0, (ticks - prev) * tickScale) : 0.0;
        const double memPct = std::max(0.0, rss * memScale);

        procs.push_back({e.pid, name, state, cpu, memPct, qint64(rss * m_pageSize / 1024), qint64(vsize / 1024), int(threads)});
    }

    m_prevProcTicks = std::move(newTicks);

    std::sort(procs.begin(), procs.end(), [](const ProcInfo& a, const ProcInfo& b) { return a.cpu > b.cpu; });

    QVariantList result;
    result.reserve(procs.size());
    for (const auto& p : procs)
    {
        QVariantMap m;
        m["pid"] = p.pid;
        m["name"] = p.name;
        m["state"] = QString(QChar(p.state));
        m["cpu"] = p.cpu;
        m["mem"] = p.memPct;
        m["memKib"] = p.memKib;
        m["virtKib"] = p.virtKib;
        m["threads"] = p.threads;
        result.append(m);
    }
    m_processes = std::move(result);
    emit procsUpdated();
}
