#include "nixgen.hpp"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QVariantMap>
#include <sys/stat.h>

static QString readFile(const QString& path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    return QString::fromUtf8(f.readAll()).trimmed();
}

NixGenProvider::NixGenProvider(QObject* parent) : QObject(parent) { readGenerations(); }

void NixGenProvider::refresh() { readGenerations(); }

void NixGenProvider::readGenerations()
{
    const QString profileDir = QStringLiteral("/nix/var/nix/profiles");

    // Resolve what the "system" profile currently points to (one symlink level)
    const QString currentLink = QFileInfo(profileDir + "/system").symLinkTarget();

    // The booted generation's store path
    const QString bootedStorePath = QFileInfo("/run/booted-system").symLinkTarget();

    QDir dir(profileDir);
    dir.setNameFilters({"system-*-link"});
    const auto entries = dir.entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::System, QDir::Name);

    static const QRegularExpression re(R"(system-(\d+)-link)");

    QVariantList gens;
    for (const QFileInfo& fi : entries)
    {
        const auto m = re.match(fi.fileName());
        if (!m.hasMatch())
            continue;

        const int num = m.captured(1).toInt();
        const QString storePath = fi.symLinkTarget();
        const QString ver = readFile(storePath + "/nixos-version");

        struct stat st{};
        QString date;
        if (lstat(fi.absoluteFilePath().toUtf8().constData(), &st) == 0)
            date = QDateTime::fromSecsSinceEpoch(st.st_mtime).toString("yyyy-MM-dd HH:mm");
        else
            date = QStringLiteral("unknown");

        QVariantMap entry;
        entry["number"] = num;
        entry["date"] = date;
        entry["storePath"] = storePath;
        entry["nixosVersion"] = ver.isEmpty() ? QStringLiteral("unknown") : ver;
        entry["current"] = (fi.absoluteFilePath() == currentLink);
        entry["booted"] = (!bootedStorePath.isEmpty() && storePath == bootedStorePath);

        // prepend so newest generation ends up first
        gens.prepend(entry);
    }

    m_generations = std::move(gens);
    emit generationsChanged();
}
