#include "hwprovider.hpp"

#include <algorithm>
#include <sys/utsname.h>

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QTextStream>

HwProvider::HwProvider(QObject* parent) : QObject(parent)
{
    parseIdFile("/etc/quickshell/pci.ids", m_pciVendors, m_pciIds);
    parseIdFile("/etc/quickshell/usb.ids", m_usbVendors, m_usbIds);
    loadSysInfo();
    tickUptime();
    loadPci();
    loadUsb();

    m_uptimeTimer.setInterval(60'000);
    m_uptimeTimer.setSingleShot(false);
    connect(&m_uptimeTimer, &QTimer::timeout, this, &HwProvider::tickUptime);
    m_uptimeTimer.start();
}

void HwProvider::refresh()
{
    loadSysInfo();
    tickUptime();
    loadPci();
    loadUsb();
}

QString HwProvider::file(const QString& path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    return QString::fromUtf8(f.readAll());
}

void HwProvider::loadSysInfo()
{
    m_hostname = file("/proc/sys/kernel/hostname").trimmed();
    m_kernel = file("/proc/sys/kernel/osrelease").trimmed();

    const QString cpuinfo = file("/proc/cpuinfo");
    const QRegularExpression modelRe(R"(^model name\s*:\s*(.+))", QRegularExpression::MultilineOption);
    const auto m = modelRe.match(cpuinfo);
    if (m.hasMatch())
    {
        m_cpu = m.captured(1).replace("(R)", "").replace("(TM)", "").replace(QRegularExpression(R"(\s+)"), " ").trimmed();
    }

    struct utsname uts{};
    if (::uname(&uts) == 0)
        m_arch = QString::fromLatin1(uts.machine);

    emit sysInfoChanged();
}

void HwProvider::tickUptime()
{
    const QString raw = file("/proc/uptime");
    const double s = raw.split(' ').value(0).toDouble();
    const int hours = static_cast<int>(s) / 3600;
    const int mins = (static_cast<int>(s) % 3600) / 60;
    m_uptime = QString::number(hours) + "h " + QString::number(mins) + "m";
    emit uptimeChanged();
}

void HwProvider::parseIdFile(const QString& path, QHash<QString, QString>& vendors, QHash<QString, QString>& devices)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return;

    QTextStream ts(&f);
    QString curVid;
    while (!ts.atEnd())
    {
        const QString ln = ts.readLine();
        if (ln.startsWith('#') || ln.isEmpty())
            continue;

        if (!ln.startsWith('\t'))
        {
            if (ln.size() >= 6)
            {
                bool ok;
                ln.left(4).toUInt(&ok, 16);
                if (ok)
                {
                    curVid = ln.left(4).toLower();
                    vendors[curVid] = ln.mid(6).trimmed();
                }
                else
                {
                    curVid.clear();
                }
            }
        }
        else if (!curVid.isEmpty() && !ln.startsWith("\t\t") && ln.size() >= 8)
        {
            bool ok;
            ln.mid(1, 4).toUInt(&ok, 16);
            if (ok)
                devices[curVid + ":" + ln.mid(1, 4).toLower()] = ln.mid(7).trimmed();
        }
    }
}

QString HwProvider::lookupId(const QHash<QString, QString>& vendors, const QHash<QString, QString>& devices, const QString& vid, const QString& did)
{
    const QString vn = vendors.value(vid);
    const QString dn = devices.value(vid + ":" + did);
    if (vn.isEmpty() && dn.isEmpty())
        return vid + ":" + did;
    if (dn.isEmpty())
        return vn + " [" + did + "]";
    if (vn.isEmpty())
        return dn;
    return vn + " " + dn;
}

QString HwProvider::pciClassName(int classCode)
{
    switch (classCode >> 8)
    {
    case 0x01:
        return "Storage";
    case 0x02:
        return "Network";
    case 0x03:
        return "Display";
    case 0x04:
        return "Multimedia";
    case 0x05:
        return "Memory";
    case 0x06:
        return "Bridge";
    case 0x07:
        return "Communication";
    case 0x08:
        return "System";
    case 0x09:
        return "Input";
    case 0x0b:
        return "Processor";
    case 0x0c:
        return "Serial Bus";
    case 0x0d:
        return "Wireless";
    case 0x10:
        return "Encryption";
    case 0x11:
        return "Signal Processing";
    case 0x40:
        return "Co-processor";
    default:
        return {};
    }
}

QString HwProvider::usbSpeedLabel(int mbs)
{
    if (mbs >= 20000)
        return "USB4 Gen3×2";
    if (mbs >= 10000)
        return "USB 3.2 Gen2";
    if (mbs >= 5000)
        return "USB 3.2 Gen1";
    if (mbs >= 480)
        return "USB 2.0";
    if (mbs >= 12)
        return "USB 1.1";
    if (mbs >= 1)
        return "USB 1.0";
    return {};
}

void HwProvider::loadPci()
{
    const QString base = "/sys/bus/pci/devices";
    QDir dir(base);
    if (!dir.exists())
        return;

    struct PciEntry
    {
        QString canonical;
        QString slot, vid, did, drv;
        int depth;
    };
    QList<PciEntry> list;

    const QRegularExpression slotRe(R"(^PCI_SLOT_NAME=(.+))", QRegularExpression::MultilineOption);
    const QRegularExpression idRe(R"(^PCI_ID=([0-9a-fA-F]{4}):([0-9a-fA-F]{4}))", QRegularExpression::MultilineOption);
    const QRegularExpression drvRe(R"(^DRIVER=(.+))", QRegularExpression::MultilineOption);

    for (const QString& name : dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot))
    {
        const QString link = base + "/" + name;
        const QString canonical = QFileInfo(link).canonicalFilePath();
        if (canonical.isEmpty())
            continue;

        const QString uevent = file(link + "/uevent");
        const auto idM = idRe.match(uevent);
        if (!idM.hasMatch())
            continue;

        const auto slotM = slotRe.match(uevent);
        const auto drvM = drvRe.match(uevent);

        // /sys/devices/pci0000:00/slot → 4 path parts → depth 0
        // /sys/devices/pci0000:00/slot/slot2 → 5 parts → depth 1
        const int depth = qMax(0, canonical.split('/', Qt::SkipEmptyParts).size() - 4);

        list.append(
            {canonical, slotM.hasMatch() ? slotM.captured(1).trimmed() : name, idM.captured(1).toLower(), idM.captured(2).toLower(),
             drvM.hasMatch() ? drvM.captured(1).trimmed() : QString(), depth}
        );
    }

    std::sort(list.begin(), list.end(), [](const PciEntry& a, const PciEntry& b) { return a.canonical < b.canonical; });

    m_pciDevices.clear();
    for (const PciEntry& e : list)
    {
        QVariantMap map;
        map["slot"] = e.slot;
        map["name"] = lookupId(m_pciVendors, m_pciIds, e.vid, e.did);
        map["drv"] = e.drv;
        map["depth"] = e.depth;
        m_pciDevices.append(map);
    }
    emit pciChanged();
}

void HwProvider::loadUsb()
{
    const QString base = "/sys/bus/usb/devices";
    QDir dir(base);
    if (!dir.exists())
        return;

    struct UsbEntry
    {
        int hostNum;
        QList<int> ports;
        QString name, speed;
        bool isHub;
        int depth;
    };
    QList<UsbEntry> list;

    const QRegularExpression drvRe(R"(^DRIVER=(.+))", QRegularExpression::MultilineOption);

    for (const QString& name : dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot))
    {
        if (name.contains(':'))
            continue;

        const QString devDir = base + "/" + name;
        int hostNum;
        QList<int> ports;
        int depth;

        if (name.startsWith("usb"))
        {
            hostNum = name.mid(3).toInt();
            depth = 0;
        }
        else
        {
            const int dash = name.indexOf('-');
            if (dash < 0)
                continue;
            hostNum = name.left(dash).toInt();
            for (const QString& p : name.mid(dash + 1).split('.'))
                ports.append(p.toInt());
            depth = ports.size();
        }

        const QString vid = file(devDir + "/idVendor").trimmed().toLower();
        const QString pid = file(devDir + "/idProduct").trimmed().toLower();
        if (vid.isEmpty() || pid.isEmpty())
            continue;

        const QString uevent = file(devDir + "/uevent");
        const auto drvM = drvRe.match(uevent);
        const bool isHub = drvM.hasMatch() && drvM.captured(1).trimmed() == "hub";

        const int mbs = file(devDir + "/speed").trimmed().toInt();

        list.append({hostNum, ports, lookupId(m_usbVendors, m_usbIds, vid, pid), usbSpeedLabel(mbs), isHub, depth});
    }

    std::sort(list.begin(), list.end(), [](const UsbEntry& a, const UsbEntry& b) {
        if (a.hostNum != b.hostNum)
            return a.hostNum < b.hostNum;
        const int n = qMin(a.ports.size(), b.ports.size());
        for (int i = 0; i < n; i++)
        {
            if (a.ports[i] != b.ports[i])
                return a.ports[i] < b.ports[i];
        }
        return a.ports.size() < b.ports.size();
    });

    m_usbDevices.clear();
    for (const UsbEntry& e : list)
    {
        QVariantMap map;
        map["name"] = e.name;
        map["speed"] = e.speed;
        map["isHub"] = e.isHub;
        map["depth"] = e.depth;
        m_usbDevices.append(map);
    }
    emit usbChanged();
}
