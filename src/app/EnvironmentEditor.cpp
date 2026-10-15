#include "app/EnvironmentEditor.h"

#include <QCoreApplication>
#include <QPointer>

#include "app/Session.h"

namespace lv {

namespace {


Environment::Auth toCore(EnvironmentEditor::Auth a)
{
    switch (a) {
        case EnvironmentEditor::Auth::Token: return Environment::Auth::Token;
        case EnvironmentEditor::Auth::None: return Environment::Auth::None;
        case EnvironmentEditor::Auth::Basic: break;
    }
    return Environment::Auth::Basic;
}

EnvironmentEditor::Auth fromCore(Environment::Auth a)
{
    switch (a) {
        case Environment::Auth::Token: return EnvironmentEditor::Auth::Token;
        case Environment::Auth::None: return EnvironmentEditor::Auth::None;
        case Environment::Auth::Basic: break;
    }
    return EnvironmentEditor::Auth::Basic;
}

} // namespace

EnvironmentEditor::EnvironmentEditor(QObject* parent)
    : EnvironmentEditor((Q_ASSERT_X(Session::instance(), "EnvironmentEditor", "no Session instance"), *Session::instance()), parent)
{
}

EnvironmentEditor::EnvironmentEditor(Session& session, QObject* parent)
    : QObject(parent), m_session(&session),
      m_discovery(std::make_unique<LabelDiscovery>(session.services().http(), session.services().classifyOptions()))
{
    connect(m_discovery.get(), &LabelDiscovery::finished, this, [this](const DiscoveryResult& r) {
        const int ms = int(m_testTimer.elapsed());
        setTest(TestState::Passed,
                QCoreApplication::translate("EnvironmentEditor", "Found %n namespace(s) · labels %1 / %2 · %3 ms", nullptr, int(r.streams.size()))
                    .arg(r.nsLabel, r.appLabel).arg(ms));
    });
    connect(m_discovery.get(), &LabelDiscovery::failed, this, [this](const RequestError& e) {
        const ErrorInfo info = ErrorInfo::from(e, m_name, QUrl(m_url).host());
        setTest(TestState::Failed, info.title, info);
    });
    createNew();
}

EnvironmentEditor::~EnvironmentEditor() = default;

void EnvironmentEditor::load(const QString& id)
{
    const auto env = m_session->services().environments().find(id);
    if (!env) return;
    m_discovery->cancel();
    m_id = env->id;
    m_isNew = false;
    m_name = env->name;
    m_color = env->color;
    m_url = env->url.toString();
    m_uid = env->datasourceUid;
    m_user = env->user;
    m_auth = fromCore(env->auth);
    m_password.clear();
    m_token.clear();
    setTest(TestState::Idle, {});
    emit loaded();
    emit formChanged();

    QPointer<EnvironmentEditor> self(this);
    const QString loadedId = m_id;
    m_session->services().secrets().read(env->passwordKey(), [self, loadedId](bool, const QString& v) {
        if (!self || self->m_id != loadedId) return;
        self->m_password = v;
        emit self->formChanged();
    });
    m_session->services().secrets().read(env->tokenKey(), [self, loadedId](bool, const QString& v) {
        if (!self || self->m_id != loadedId) return;
        self->m_token = v;
        emit self->formChanged();
    });
}

void EnvironmentEditor::createNew()
{
    m_discovery->cancel();
    m_id.clear();
    m_isNew = true;
    m_name.clear();
    QStringList used;
    for (const Environment& e : m_session->services().environments().environments()) used << e.color;
    m_color = environmentColors().constLast();
    for (const QString& c : environmentColors()) {
        if (used.contains(c)) continue;
        m_color = c;
        break;
    }
    m_url.clear();
    m_uid.clear();
    m_user.clear();
    m_password.clear();
    m_token.clear();
    m_auth = Auth::Basic;
    setTest(TestState::Idle, {});
    emit loaded();
    emit formChanged();
}

Environment EnvironmentEditor::toEnvironment() const
{
    Environment e;
    e.id = m_id;
    e.name = m_name.trimmed();
    e.color = m_color;
    e.url = QUrl(m_url.trimmed());
    e.datasourceUid = m_uid.trimmed();
    e.user = m_user.trimmed();
    e.auth = toCore(m_auth);
    return e;
}

QString EnvironmentEditor::validationError() const
{
    const Environment e = toEnvironment();
    if (e.name.isEmpty()) return QCoreApplication::translate("EnvironmentEditor", "Give the environment a name.");
    for (const Environment& other : m_session->services().environments().environments()) {
        if (other.id != e.id && other.name.compare(e.name, Qt::CaseInsensitive) == 0)
            return QCoreApplication::translate("EnvironmentEditor", "An environment named %1 already exists.").arg(e.name);
    }
    if (!m_url.trimmed().isEmpty()) {
        const QUrl u = e.url;
        if (!u.isValid() || (u.scheme() != u"https" && u.scheme() != u"http") || u.host().isEmpty())
            return QCoreApplication::translate("EnvironmentEditor", "The Grafana URL must start with https:// or http://.");
    }
    return {};
}

bool EnvironmentEditor::canRemove() const
{
    return !m_isNew && m_session->services().environments().environments().size() > 1;
}

bool EnvironmentEditor::secretsSecure() const
{
    return m_session->services().secrets().isSecure();
}

void EnvironmentEditor::setTest(TestState state, const QString& message, const ErrorInfo& error)
{
    m_testState = state;
    m_testMessage = message;
    m_testError = error;
    emit testChanged();
}

void EnvironmentEditor::testConnection()
{
    if (!validationError().isEmpty()) {
        setTest(TestState::Failed, validationError());
        return;
    }
    const Environment e = toEnvironment();
    m_testTimer.start();
    setTest(TestState::Testing, QCoreApplication::translate("EnvironmentEditor", "Connecting…"));
    m_discovery->start(e.connection(m_password, m_token));
}

bool EnvironmentEditor::save(bool makeCurrent)
{
    if (!validationError().isEmpty()) {
        emit formChanged();
        return false;
    }
    AppServices& services = m_session->services();
    const Environment env = services.environments().upsert(toEnvironment());
    m_id = env.id;
    m_isNew = false;

    // Keep only the secret the chosen auth uses.
    auto ignore = [](bool) {};
    if (env.auth == Environment::Auth::Basic && !m_password.isEmpty())
        services.secrets().write(env.passwordKey(), m_password, ignore);
    else
        services.secrets().remove(env.passwordKey(), ignore);
    if (env.auth == Environment::Auth::Token && !m_token.isEmpty())
        services.secrets().write(env.tokenKey(), m_token, ignore);
    else
        services.secrets().remove(env.tokenKey(), ignore);

    if (makeCurrent) services.environments().setCurrent(env.id);
    emit loaded();
    emit saved(env.id);
    m_session->environmentsEdited(env.id);
    return true;
}

bool EnvironmentEditor::remove()
{
    if (!canRemove()) return false;
    AppServices& services = m_session->services();
    const auto env = services.environments().find(m_id);
    if (!env || !services.environments().remove(m_id)) return false;
    services.secrets().remove(env->passwordKey(), [](bool) {});
    services.secrets().remove(env->tokenKey(), [](bool) {});
    const QString id = m_id;
    emit removed(id);
    m_session->environmentsEdited(id);
    createNew();
    return true;
}

} // namespace lv
