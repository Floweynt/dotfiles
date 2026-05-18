#include <QDBusMetaType>
#include <QQmlExtensionPlugin>
#include <qqml.h>
#include "polkitagent.hpp"

static QObject* polkitAgentFactory(QQmlEngine*, QJSEngine*) {
    return new PolkitAgent();
}

class PolkitQmlPlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
public:
    void registerTypes(const char* uri) override {
        qDBusRegisterMetaType<PolkitIdentity>();
        qmlRegisterSingletonType<PolkitAgent>(uri, 1, 0, "PolkitAgent", polkitAgentFactory);
    }
};

#include "plugin.moc"
