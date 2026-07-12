#include "polkitagent.hpp"

#include <QDBusMetaType>
#include <QDebug>

#include <pwd.h>

QDBusArgument& operator<<(QDBusArgument& arg, const PolkitIdentity& id)
{
    arg.beginStructure();
    arg << id.kind << id.attrs;
    arg.endStructure();
    return arg;
}

const QDBusArgument& operator>>(const QDBusArgument& arg, PolkitIdentity& id)
{
    arg.beginStructure();
    arg >> id.kind >> id.attrs;
    arg.endStructure();
    return arg;
}

static constexpr const char* kAgentPath = "/org/freedesktop/PolicyKit1/AuthenticationAgent";
static constexpr const char* kAuthorityService = "org.freedesktop.PolicyKit1";
static constexpr const char* kAuthorityPath = "/org/freedesktop/PolicyKit1/Authority";
static constexpr const char* kAuthorityIface = "org.freedesktop.PolicyKit1.Authority";
// polkit 127+ uses systemd socket activation; systemd spawns the helper as root
static constexpr const char* kHelperSocket = "/run/polkit/agent-helper.socket";

QString PolkitAgent::pamUnescape(const QString& s)
{
    QString out;
    out.reserve(s.size());
    for (int i = 0; i < s.size(); ++i)
    {
        if (s[i] == QLatin1Char('\\') && i + 1 < s.size())
        {
            ++i;
            switch (s[i].toLatin1())
            {
            case 'n':
                out += QLatin1Char('\n');
                break;
            case 't':
                out += QLatin1Char('\t');
                break;
            case 'r':
                out += QLatin1Char('\r');
                break;
            case '\\':
                out += QLatin1Char('\\');
                break;
            case '"':
                out += QLatin1Char('"');
                break;
            default:
                out += QLatin1Char('\\');
                out += s[i];
                break;
            }
        }
        else
        {
            out += s[i];
        }
    }
    return out;
}

PolkitAgent::PolkitAgent(QObject* parent) : QObject(parent), m_bus(QDBusConnection::systemBus()), m_replyConn(QDBusConnection::systemBus())
{
    m_obj = new PolkitAgentObject(this);

    if (!m_bus.registerVirtualObject(kAgentPath, m_obj))
    {
        qWarning("PolkitAgent: failed to register D-Bus object at %s: %s", kAgentPath, qPrintable(m_bus.lastError().message()));
        return;
    }

    PolkitIdentity subject;
    subject.kind = QStringLiteral("unix-session");
    subject.attrs[QStringLiteral("session-id")] = QString::fromLocal8Bit(qgetenv("XDG_SESSION_ID"));

    QDBusMessage reg =
        QDBusMessage::createMethodCall(kAuthorityService, kAuthorityPath, kAuthorityIface, QStringLiteral("RegisterAuthenticationAgent"));
    reg << QVariant::fromValue(subject) << QStringLiteral("en_US.UTF-8") << QString(kAgentPath);

    QDBusMessage reply = m_bus.call(reg, QDBus::Block, 5000);
    if (reply.type() == QDBusMessage::ErrorMessage)
    {
        qWarning("PolkitAgent: RegisterAuthenticationAgent failed: %s", qPrintable(reply.errorMessage()));
    }
    else
    {
        qDebug() << "PolkitAgent: registered successfully";
    }
}

PolkitAgent::~PolkitAgent()
{
    if (m_obj)
    {
        if (m_helper)
        {
            m_helper->abort();
            m_helper->deleteLater();
            m_helper = nullptr;
        }

        PolkitIdentity subject;
        subject.kind = QStringLiteral("unix-session");
        subject.attrs[QStringLiteral("session-id")] = QString::fromLocal8Bit(qgetenv("XDG_SESSION_ID"));

        QDBusMessage unreg =
            QDBusMessage::createMethodCall(kAuthorityService, kAuthorityPath, kAuthorityIface, QStringLiteral("UnregisterAuthenticationAgent"));
        unreg << QVariant::fromValue(subject) << QString(kAgentPath);
        m_bus.call(unreg, QDBus::Block, 2000);

        m_bus.unregisterObject(kAgentPath);
        delete m_obj;
    }
}

void PolkitAgent::connectToHelper()
{
    if (m_helper)
    {
        m_helper->disconnect(this);
        m_helper->abort();
        m_helper->deleteLater();
        m_helper = nullptr;
    }

    m_readBuffer.clear();
    m_helper = new QLocalSocket(this);

    connect(m_helper, &QLocalSocket::connected, this, &PolkitAgent::onHelperConnected);
    connect(m_helper, &QLocalSocket::readyRead, this, &PolkitAgent::onHelperReadyRead);
    connect(m_helper, &QLocalSocket::disconnected, this, &PolkitAgent::onHelperDisconnected);
    connect(m_helper, &QLocalSocket::errorOccurred, this, [](QLocalSocket::LocalSocketError err) {
        qWarning() << "PolkitAgent: socket error:" << err;
    });

    m_helper->connectToServer(QString(kHelperSocket));
}

void PolkitAgent::onHelperConnected()
{
    // Socket-activated mode: helper reads username first, then cookie
    m_helper->write((m_user + QLatin1Char('\n')).toUtf8());
    m_helper->write((m_cookie + QLatin1Char('\n')).toUtf8());
    m_helper->flush();
}

void PolkitAgent::onHelperReadyRead()
{
    m_readBuffer += QString::fromUtf8(m_helper->readAll());

    int nl;
    while ((nl = m_readBuffer.indexOf(QLatin1Char('\n'))) != -1)
    {
        const QString line = m_readBuffer.left(nl);
        m_readBuffer.remove(0, nl + 1);

        if (line == QLatin1String("SUCCESS"))
        {
            // Helper already called AuthenticationAgentResponse as root
            sendReply();
            resetState();
            return;
        }
        else if (line == QLatin1String("FAILURE"))
        {
            m_helper->disconnect(this);
            m_helper->deleteLater();
            m_helper = nullptr;
            if (m_lastError.isEmpty())
                m_lastError = QStringLiteral("Authentication failed. Please try again.");
            m_busy = false;
            emit busyChanged();
            emit lastErrorChanged();
        }
        else if (line.startsWith(QLatin1String("PAM_PROMPT_ECHO_OFF ")) || line.startsWith(QLatin1String("PAM_PROMPT_ECHO_ON ")))
        {
            const int sep = line.indexOf(QLatin1Char(' '));
            const QString prompt = pamUnescape(line.mid(sep + 1));
            qDebug() << "PolkitAgent: PAM prompt:" << prompt;

            if (!m_pendingResponse.isEmpty())
            {
                // Retry path: send stored password immediately
                const QString resp = m_pendingResponse;
                m_pendingResponse.clear();
                m_helper->write((resp + QLatin1Char('\n')).toUtf8());
                m_helper->flush();
            }
            else
            {
                // First attempt: let user type
                m_lastError.clear();
                m_busy = false;
                emit lastErrorChanged();
                emit busyChanged();
            }
        }
        else if (line.startsWith(QLatin1String("PAM_TEXT_INFO ")))
        {
            const QString text = pamUnescape(line.mid(14));
            qDebug() << "PolkitAgent: PAM info:" << text;
            const QString lo = text.toLower();
            if (lo.contains(QLatin1String("finger")) || lo.contains(QLatin1String("swipe")) || lo.contains(QLatin1String("scan")))
            {
                m_fingerprintAvailable = true;
                m_fingerprintStatus = text;
                emit fingerprintAvailableChanged();
                emit fingerprintStatusChanged();
            }
        }
        else if (line.startsWith(QLatin1String("PAM_ERROR_MSG ")))
        {
            const QString text = pamUnescape(line.mid(14));
            qDebug() << "PolkitAgent: PAM error:" << text;
            m_lastError = text;
            emit lastErrorChanged();
        }
    }
}

void PolkitAgent::onHelperDisconnected()
{
    if (m_helper)
    {
        m_helper->deleteLater();
        m_helper = nullptr;
    }
    if (!m_cookie.isEmpty() && m_busy)
    {
        if (m_lastError.isEmpty())
            m_lastError = QStringLiteral("Authentication failed. Please try again.");
        sendReply();
        resetState();
    }
}

void PolkitAgent::onBeginAuth(
    const QString& cookie, const QString& actionId, const QString& message, const QString& iconName, const QString& user, uint uid,
    const QDBusConnection& conn, const QDBusMessage& msg
)
{
    if (!m_cookie.isEmpty())
    {
        qWarning() << "PolkitAgent: rejecting BeginAuth; another auth in progress";
        conn.send(msg.createErrorReply(QDBusError::Failed, QStringLiteral("Another authentication is in progress")));
        return;
    }

    m_cookie = cookie;
    m_actionId = actionId;
    m_message = message;
    m_iconName = iconName;
    m_user = user;
    m_uid = uid;
    m_lastError = QString();
    m_busy = true;
    m_pendingResponse.clear();
    m_fingerprintAvailable = false;
    m_fingerprintStatus.clear();
    m_replyConn = conn;
    m_replyMsg = msg;

    emit activeChanged();
    emit busyChanged();
    emit lastErrorChanged();
    emit authRequested(cookie, actionId, message, iconName, user);

    connectToHelper();
}

void PolkitAgent::onCancelAuth(const QString& cookie, const QDBusConnection& conn, const QDBusMessage& msg)
{
    conn.send(msg.createReply());
    if (cookie == m_cookie)
        cancel(cookie);
}

void PolkitAgent::authenticate(const QString& cookie, const QString& password)
{
    if (cookie != m_cookie)
        return;

    m_lastError.clear();
    m_busy = true;
    emit lastErrorChanged();
    emit busyChanged();

    if (m_helper && m_helper->state() == QLocalSocket::ConnectedState)
    {
        m_helper->write((password + QLatin1Char('\n')).toUtf8());
        m_helper->flush();
    }
    else
    {
        m_pendingResponse = password;
        connectToHelper();
    }
}

void PolkitAgent::cancel(const QString& cookie)
{
    if (cookie != m_cookie)
        return;
    sendReply();
    resetState();
}

void PolkitAgent::sendReply() { m_replyConn.send(m_replyMsg.createReply()); }

void PolkitAgent::resetState()
{
    if (m_helper)
    {
        m_helper->disconnect(this);
        m_helper->abort();
        m_helper->deleteLater();
        m_helper = nullptr;
    }
    m_cookie.clear();
    m_actionId.clear();
    m_message.clear();
    m_iconName.clear();
    m_user.clear();
    m_uid = 0;
    m_lastError.clear();
    m_busy = false;
    m_readBuffer.clear();
    m_pendingResponse.clear();
    if (m_fingerprintAvailable)
    {
        m_fingerprintAvailable = false;
        m_fingerprintStatus.clear();
        emit fingerprintAvailableChanged();
        emit fingerprintStatusChanged();
    }
    emit activeChanged();
    emit busyChanged();
    emit lastErrorChanged();
}

static constexpr const char* kAgentIface = "org.freedesktop.PolicyKit1.AuthenticationAgent";

QString PolkitAgentObject::introspect(const QString&) const
{
    return QStringLiteral(
        "<interface name=\"org.freedesktop.PolicyKit1.AuthenticationAgent\">"
        "  <method name=\"BeginAuthentication\">"
        "    <arg type=\"s\"         name=\"action_id\"   direction=\"in\"/>"
        "    <arg type=\"s\"         name=\"message\"     direction=\"in\"/>"
        "    <arg type=\"s\"         name=\"icon_name\"   direction=\"in\"/>"
        "    <arg type=\"a{ss}\"     name=\"details\"     direction=\"in\"/>"
        "    <arg type=\"s\"         name=\"cookie\"      direction=\"in\"/>"
        "    <arg type=\"a(sa{sv})\" name=\"identities\"  direction=\"in\"/>"
        "  </method>"
        "  <method name=\"CancelAuthentication\">"
        "    <arg type=\"s\" name=\"cookie\" direction=\"in\"/>"
        "  </method>"
        "</interface>"
    );
}

bool PolkitAgentObject::handleMessage(const QDBusMessage& msg, const QDBusConnection& conn)
{
    if (msg.interface() != QLatin1String(kAgentIface))
        return false;

    if (msg.member() == QLatin1String("BeginAuthentication"))
    {
        auto args = msg.arguments();
        if (args.size() < 6)
            return false;

        const QString actionId = args[0].toString();
        const QString message = args[1].toString();
        const QString iconName = args[2].toString();
        const QString cookie = args[4].toString();

        QString user;
        uint uid = 0;
        if (args[5].canConvert<QDBusArgument>())
        {
            const QDBusArgument idArg = args[5].value<QDBusArgument>();
            idArg.beginArray();
            while (!idArg.atEnd())
            {
                PolkitIdentity id;
                idArg >> id;
                if (id.kind == QLatin1String("unix-user") && id.attrs.contains(QStringLiteral("uid")))
                {
                    uid = id.attrs[QStringLiteral("uid")].toUInt();
                    if (struct passwd* pw = getpwuid(uid))
                        user = QString::fromLocal8Bit(pw->pw_name);
                    break;
                }
            }
            idArg.endArray();
        }

        m_agent->onBeginAuth(cookie, actionId, message, iconName, user, uid, conn, msg);
        return true;
    }

    if (msg.member() == QLatin1String("CancelAuthentication"))
    {
        const QString cookie = msg.arguments().value(0).toString();
        m_agent->onCancelAuth(cookie, conn, msg);
        return true;
    }

    return false;
}
