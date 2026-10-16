#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>
#include <functional>

namespace lv {

// What the device offers beyond Qt (Session.device): the system "Send…" sheet
// and saving / opening a file the user picks. The platform plugs these in
// (the browser page through WebShell); without them the UI keeps to copying.
class DeviceBridge : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Use Session.device")
    Q_PROPERTY(bool canShare READ canShare NOTIFY changed)
    Q_PROPERTY(bool canExchangeFiles READ canExchangeFiles NOTIFY changed)

public:
    using ShareHandler = std::function<void(const QString& title, const QString& url)>;
    using SaveHandler = std::function<void(const QString& fileName, const QString& content)>;
    using OpenHandler = std::function<void()>;      // answers with fileOpened()

    explicit DeviceBridge(QObject* parent = nullptr) : QObject(parent) {}

    bool canShare() const { return bool(m_share); }
    bool canExchangeFiles() const { return m_save && m_open; }

    // The platform side.
    void setShareHandler(ShareHandler handler);
    void setFileHandlers(SaveHandler save, OpenHandler open);
    // The text of the file the user picked after openFile().
    void deliverFile(const QString& content) { emit fileOpened(content); }

    Q_INVOKABLE void share(const QString& title, const QString& url);
    Q_INVOKABLE void saveFile(const QString& fileName, const QString& content);
    Q_INVOKABLE void openFile();

signals:
    void changed();
    void fileOpened(const QString& content);

private:
    ShareHandler m_share;
    SaveHandler m_save;
    OpenHandler m_open;
};

} // namespace lv
