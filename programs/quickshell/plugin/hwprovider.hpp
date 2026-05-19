#pragma once
#include <QHash>
#include <QObject>
#include <QString>
#include <QTimer>
#include <QVariantList>

class HwProvider : public QObject {
    Q_OBJECT

    Q_PROPERTY(QString hostname   READ hostname   NOTIFY sysInfoChanged)
    Q_PROPERTY(QString kernel     READ kernel     NOTIFY sysInfoChanged)
    Q_PROPERTY(QString cpu        READ cpu        NOTIFY sysInfoChanged)
    Q_PROPERTY(QString arch       READ arch       NOTIFY sysInfoChanged)
    Q_PROPERTY(QString uptime     READ uptime     NOTIFY uptimeChanged)
    Q_PROPERTY(QVariantList pciDevices READ pciDevices NOTIFY pciChanged)
    Q_PROPERTY(QVariantList usbDevices READ usbDevices NOTIFY usbChanged)

public:
    explicit HwProvider(QObject* parent = nullptr);

    QString      hostname()   const { return m_hostname;   }
    QString      kernel()     const { return m_kernel;     }
    QString      cpu()        const { return m_cpu;        }
    QString      arch()       const { return m_arch;       }
    QString      uptime()     const { return m_uptime;     }
    QVariantList pciDevices() const { return m_pciDevices; }
    QVariantList usbDevices() const { return m_usbDevices; }

    Q_INVOKABLE void refresh();

signals:
    void sysInfoChanged();
    void uptimeChanged();
    void pciChanged();
    void usbChanged();

private:
    void loadSysInfo();
    void loadPci();
    void loadUsb();
    void tickUptime();

    static QString file(const QString& path);
    static void parseIdFile(const QString& path,
                            QHash<QString,QString>& vendors,
                            QHash<QString,QString>& devices);
    static QString lookupId(const QHash<QString,QString>& vendors,
                            const QHash<QString,QString>& devices,
                            const QString& vid, const QString& did);
    static QString pciClassName(int classCode);
    static QString usbSpeedLabel(int mbs);

    QString      m_hostname, m_kernel, m_cpu, m_arch, m_uptime;
    QVariantList m_pciDevices, m_usbDevices;

    QHash<QString,QString> m_pciVendors, m_pciIds;
    QHash<QString,QString> m_usbVendors, m_usbIds;

    QTimer m_uptimeTimer;
};
