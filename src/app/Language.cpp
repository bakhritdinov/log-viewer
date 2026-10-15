#include "app/Language.h"

#include <QCoreApplication>
#include <QLocale>
#include <QQmlEngine>

#include "core/storage/KeyValueStore.h"

namespace lv {

namespace {

QPointer<Language> g_instance;
const QString kSettingsKey = QStringLiteral("ui/language");

struct Spec {
    const char* code;
    const char* nativeName;   // shown in its own language, never translated
    QLocale locale;
};

const QList<Spec>& specs()
{
    static const QList<Spec> list = {
        { "ru", "Русский", QLocale(QLocale::Russian, QLocale::Russia) },
        { "uz", "Oʻzbekcha", QLocale(QLocale::Uzbek, QLocale::LatinScript, QLocale::Uzbekistan) },
        { "en", "English", QLocale(QLocale::English, QLocale::UnitedStates) },
    };
    return list;
}

} // namespace

Language::Language(KeyValueStore& settings, QObject* parent) : QObject(parent), m_settings(settings) {}

Language::~Language()
{
    if (m_translator) QCoreApplication::removeTranslator(m_translator.get());
    if (g_instance == this) g_instance = nullptr;
}

void Language::setInstance(Language* language) { g_instance = language; }
Language* Language::instance() { return g_instance; }

Language* Language::create(QQmlEngine* engine, QJSEngine*)
{
    Q_ASSERT_X(g_instance, "Language::create", "Language::setInstance() must be called before QML loads");
    g_instance->attachEngine(engine);
    QJSEngine::setObjectOwnership(g_instance, QJSEngine::CppOwnership);
    return g_instance;
}

QStringList Language::supportedCodes()
{
    QStringList codes;
    for (const Spec& s : specs()) codes << QString::fromLatin1(s.code);
    return codes;
}

QVariantList Language::languages() const
{
    QVariantList out;
    for (const Spec& s : specs())
        out << QVariantMap{ { "code", QString::fromLatin1(s.code) }, { "name", QString::fromUtf8(s.nativeName) } };
    return out;
}

void Language::apply()
{
    setCode(m_settings.value(kSettingsKey, QString::fromLatin1(kDefaultCode)).toString());
}

bool Language::install(const QString& code)
{
    if (m_translator) {
        QCoreApplication::removeTranslator(m_translator.get());
        m_translator.reset();
    }
    // English is the source language; its .qm carries only the plural forms.
    auto translator = std::make_unique<QTranslator>();
    if (!translator->load(QStringLiteral(":/i18n/logviewer_%1.qm").arg(code))) return false;
    QCoreApplication::installTranslator(translator.get());
    m_translator = std::move(translator);
    return true;
}

void Language::setCode(const QString& requested)
{
    const QString code = supportedCodes().contains(requested) ? requested : QString::fromLatin1(kDefaultCode);
    const bool changed = code != m_code;
    install(code);
    for (const Spec& s : specs())
        if (code == QLatin1StringView(s.code)) QLocale::setDefault(s.locale);
    m_code = code;
    m_settings.setValue(kSettingsKey, code);
    if (m_engine) m_engine->retranslate();
    if (changed) emit codeChanged();
}

} // namespace lv
