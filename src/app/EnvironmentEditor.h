#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QtQml/qqmlregistration.h>
#include <memory>

#include "app/ErrorInfo.h"
#include "core/data/LabelDiscovery.h"
#include "core/storage/Environments.h"

namespace lv {

class AppServices;
class Session;

// Form state of one environment in Settings: edit, test the connection with
// the values as typed, save (secrets to the secret store) or remove.
// Created from QML (`EnvironmentEditor { }`); works on Session::instance().
class EnvironmentEditor : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString environmentId READ environmentId NOTIFY loaded)
    Q_PROPERTY(bool isNew READ isNew NOTIFY loaded)
    Q_PROPERTY(QString name MEMBER m_name NOTIFY formChanged)
    Q_PROPERTY(QString color MEMBER m_color NOTIFY formChanged)
    Q_PROPERTY(QString url MEMBER m_url NOTIFY formChanged)
    Q_PROPERTY(QString datasourceUid MEMBER m_uid NOTIFY formChanged)
    Q_PROPERTY(Auth auth MEMBER m_auth NOTIFY formChanged)
    Q_PROPERTY(QString user MEMBER m_user NOTIFY formChanged)
    Q_PROPERTY(QString password MEMBER m_password NOTIFY formChanged)
    Q_PROPERTY(QString token MEMBER m_token NOTIFY formChanged)
    Q_PROPERTY(QStringList colors READ colors CONSTANT)
    Q_PROPERTY(QString validationError READ validationError NOTIFY formChanged)
    Q_PROPERTY(bool canRemove READ canRemove NOTIFY loaded)
    Q_PROPERTY(bool secretsSecure READ secretsSecure CONSTANT)
    Q_PROPERTY(TestState testState READ testState NOTIFY testChanged)
    Q_PROPERTY(QString testMessage READ testMessage NOTIFY testChanged)
    Q_PROPERTY(lv::ErrorInfo testError READ testError NOTIFY testChanged)

public:
    enum class Auth { Basic, Token, None };
    Q_ENUM(Auth)
    enum class TestState { Idle, Testing, Passed, Failed };
    Q_ENUM(TestState)

    explicit EnvironmentEditor(QObject* parent = nullptr);
    // For tests: an explicit session instead of the singleton.
    EnvironmentEditor(Session& session, QObject* parent = nullptr);
    ~EnvironmentEditor() override;

    // Loads an existing environment (secrets arrive asynchronously).
    Q_INVOKABLE void load(const QString& id);
    // A blank environment with a free colour.
    Q_INVOKABLE void createNew();
    Q_INVOKABLE void testConnection();
    // Validates and stores; `makeCurrent` switches to it. Returns false on a
    // validation error (see validationError).
    Q_INVOKABLE bool save(bool makeCurrent = true);
    Q_INVOKABLE bool remove();

    QString environmentId() const { return m_id; }
    bool isNew() const { return m_isNew; }
    QStringList colors() const { return environmentColors(); }
    QString validationError() const;
    bool canRemove() const;
    bool secretsSecure() const;
    TestState testState() const { return m_testState; }
    QString testMessage() const { return m_testMessage; }
    ErrorInfo testError() const { return m_testError; }

signals:
    void loaded();
    void formChanged();
    void testChanged();
    void saved(const QString& id);
    void removed(const QString& id);

private:
    Environment toEnvironment() const;
    void setTest(TestState state, const QString& message, const ErrorInfo& error = {});

    Session* m_session;
    std::unique_ptr<LabelDiscovery> m_discovery;
    QElapsedTimer m_testTimer;

    QString m_id;
    bool m_isNew = true;
    QString m_name;
    QString m_color;
    QString m_url;
    QString m_uid;
    Auth m_auth = Auth::Basic;
    QString m_user;
    QString m_password;
    QString m_token;
    TestState m_testState = TestState::Idle;
    QString m_testMessage;
    ErrorInfo m_testError;
};

} // namespace lv
