#pragma once
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusVirtualObject>
#include <QLocalSocket>
#include <QObject>
#include <QString>
#include <QVariant>

struct PolkitIdentity {
    QString     kind;
    QVariantMap attrs;
};
Q_DECLARE_METATYPE(PolkitIdentity)

QDBusArgument&       operator<<(QDBusArgument&, const PolkitIdentity&);
const QDBusArgument& operator>>(const QDBusArgument&, PolkitIdentity&);

// ─────────────────────────────────────────────────────────────────────────────

class PolkitAgentObject;

class PolkitAgent : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool    active               READ active               NOTIFY activeChanged)
    Q_PROPERTY(bool    busy                 READ busy                 NOTIFY busyChanged)
    Q_PROPERTY(QString cookie               READ cookie               NOTIFY activeChanged)
    Q_PROPERTY(QString message              READ message              NOTIFY activeChanged)
    Q_PROPERTY(QString iconName             READ iconName             NOTIFY activeChanged)
    Q_PROPERTY(QString user                 READ user                 NOTIFY activeChanged)
    Q_PROPERTY(QString lastError            READ lastError            NOTIFY lastErrorChanged)
    Q_PROPERTY(bool    fingerprintAvailable READ fingerprintAvailable NOTIFY fingerprintAvailableChanged)
    Q_PROPERTY(QString fingerprintStatus    READ fingerprintStatus    NOTIFY fingerprintStatusChanged)

public:
    explicit PolkitAgent(QObject* parent = nullptr);
    ~PolkitAgent();

    bool    active()               const { return !m_cookie.isEmpty(); }
    bool    busy()                 const { return m_busy; }
    QString cookie()               const { return m_cookie; }
    QString message()              const { return m_message; }
    QString iconName()             const { return m_iconName; }
    QString user()                 const { return m_user; }
    QString lastError()            const { return m_lastError; }
    bool    fingerprintAvailable() const { return m_fingerprintAvailable; }
    QString fingerprintStatus()    const { return m_fingerprintStatus; }

    Q_INVOKABLE void authenticate(const QString& cookie, const QString& password);
    Q_INVOKABLE void cancel(const QString& cookie);

    void onBeginAuth(const QString& cookie, const QString& actionId,
                     const QString& message, const QString& iconName,
                     const QString& user, uint uid,
                     const QDBusConnection& conn, const QDBusMessage& msg);
    void onCancelAuth(const QString& cookie,
                      const QDBusConnection& conn, const QDBusMessage& msg);

signals:
    void activeChanged();
    void busyChanged();
    void lastErrorChanged();
    void fingerprintAvailableChanged();
    void fingerprintStatusChanged();
    void authRequested(const QString& cookie, const QString& actionId,
                       const QString& message, const QString& iconName,
                       const QString& user);

private slots:
    void onHelperConnected();
    void onHelperReadyRead();
    void onHelperDisconnected();

private:
    void connectToHelper();
    void resetState();
    void sendReply();
    static QString pamUnescape(const QString& s);

    QDBusConnection     m_bus;
    QString             m_cookie;
    QString             m_actionId;
    QString             m_message;
    QString             m_iconName;
    QString             m_user;
    uint                m_uid              = 0;
    QString             m_lastError;
    bool                m_busy             = false;
    QDBusConnection     m_replyConn;
    QDBusMessage        m_replyMsg;
    PolkitAgentObject*  m_obj              = nullptr;

    QLocalSocket*       m_helper           = nullptr;
    QString             m_readBuffer;
    QString             m_pendingResponse;

    bool                m_fingerprintAvailable = false;
    QString             m_fingerprintStatus;
};

// ─────────────────────────────────────────────────────────────────────────────

class PolkitAgentObject : public QDBusVirtualObject {
public:
    explicit PolkitAgentObject(PolkitAgent* agent) : m_agent(agent) {}
    QString introspect(const QString& path) const override;
    bool    handleMessage(const QDBusMessage& msg, const QDBusConnection& conn) override;
private:
    PolkitAgent* m_agent;
};
