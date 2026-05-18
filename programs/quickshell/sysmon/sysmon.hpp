#pragma once
#include <QHash>
#include <QList>
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QString>
#include <QVector>
#include <liburing.h>

class SysmonProvider : public QObject {
    Q_OBJECT

    Q_PROPERTY(double cpuTotal  READ cpuTotal  NOTIFY cpuUpdated)
    Q_PROPERTY(QVariantList cpuCores READ cpuCores NOTIFY cpuUpdated)
    Q_PROPERTY(double cpuTemp   READ cpuTemp   NOTIFY cpuUpdated)
    Q_PROPERTY(int    cpuFreq   READ cpuFreq   NOTIFY cpuUpdated)

    Q_PROPERTY(double memTotal  READ memTotal  NOTIFY memUpdated)
    Q_PROPERTY(double memUsed   READ memUsed   NOTIFY memUpdated)
    Q_PROPERTY(double memCached READ memCached NOTIFY memUpdated)
    Q_PROPERTY(double memFree   READ memFree   NOTIFY memUpdated)
    Q_PROPERTY(double swapTotal READ swapTotal NOTIFY memUpdated)
    Q_PROPERTY(double swapUsed  READ swapUsed  NOTIFY memUpdated)

    Q_PROPERTY(QVariantList gpus      READ gpus      NOTIFY gpusUpdated)
    Q_PROPERTY(QVariantList processes READ processes NOTIFY procsUpdated)

    Q_INVOKABLE bool killProcess(int pid, int sig = 15);

    Q_PROPERTY(double  battPct      READ battPct      NOTIFY battUpdated)
    Q_PROPERTY(bool    battCharging READ battCharging NOTIFY battUpdated)
    Q_PROPERTY(QString battStatus   READ battStatus   NOTIFY battUpdated)

    Q_PROPERTY(int interval READ interval WRITE setInterval NOTIFY intervalChanged)

public:
    explicit SysmonProvider(QObject* parent = nullptr);
    ~SysmonProvider();

    double       cpuTotal()  const { return m_cpuTotal;  }
    QVariantList cpuCores()  const { return m_cpuCores;  }
    double       cpuTemp()   const { return m_cpuTemp;   }
    int          cpuFreq()   const { return m_cpuFreq;   }

    double memTotal()  const { return m_memTotal;  }
    double memUsed()   const { return m_memUsed;   }
    double memCached() const { return m_memCached; }
    double memFree()   const { return m_memFree;   }
    double swapTotal() const { return m_swapTotal; }
    double swapUsed()  const { return m_swapUsed;  }

    QVariantList gpus()      const { return m_gpus;      }
    QVariantList processes() const { return m_processes; }

    double  battPct()      const { return m_battPct;      }
    bool    battCharging() const { return m_battCharging; }
    QString battStatus()   const { return m_battStatus;   }

    int  interval() const { return m_timer.interval(); }
    void setInterval(int ms);

signals:
    void cpuUpdated();
    void memUpdated();
    void gpusUpdated();
    void battUpdated();
    void procsUpdated();
    void intervalChanged();

private:
    void discover();
    void poll();
    void pollCpu();
    void pollMem();
    void pollGpus();
    void pollBatt();
    void pollProcs();

    static QString sysfsRead(const QString& path);
    static qint64  sysfsInt(const QString& path);

    QTimer m_timer;

    struct CpuState { qint64 idle = 0, total = 0; };
    CpuState          m_prevTotal;
    QVector<CpuState> m_prevCores;
    double            m_cpuTotal = 0;
    QVariantList      m_cpuCores;
    QString           m_k10tempPath;
    double            m_cpuTemp = 0;
    int               m_cpuFreq = 0;
    QStringList       m_cpuFreqPaths;

    double m_memTotal = 0, m_memUsed = 0, m_memCached = 0, m_memFree = 0;
    double m_swapTotal = 0, m_swapUsed = 0;

    struct GpuEntry {
        QString card, hwmon, name;
        int    busy = 0;
        qint64 vramUsed = 0, vramTotal = 1;
        int    power = 0, temp = 0, freq = 0;
        bool   active = true;
    };

    QVector<GpuEntry> m_gpuEntries;
    QVector<QString>  m_amdgpuHwmons;
    QVariantList      m_gpus;

    QString m_battCapPath, m_battStatusPath;
    double  m_battPct = -1;
    bool    m_battCharging = false;
    QString m_battStatus;

    struct ProcTick { qint64 ticks = 0; };
    QHash<int, ProcTick> m_prevProcTicks;

    struct io_uring m_procRing;
    bool            m_procRingReady = false;
    QVariantList         m_processes;
    qint64               m_totalTicksSinceLastProc = 0;
    qint64               m_memTotalKiB = 0;
    long                 m_pageSize = 4096;
    int                  m_procPollCounter = 0;
};
