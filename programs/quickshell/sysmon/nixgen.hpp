#pragma once
#include <QObject>
#include <QVariantList>
#include <QString>

class NixGenProvider : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList generations READ generations NOTIFY generationsChanged)

public:
    explicit NixGenProvider(QObject* parent = nullptr);

    QVariantList generations() const { return m_generations; }
    Q_INVOKABLE void refresh();

signals:
    void generationsChanged();

private:
    QVariantList m_generations;
    void readGenerations();
};
