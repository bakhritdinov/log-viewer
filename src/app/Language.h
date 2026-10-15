#pragma once

#include <QObject>
#include <QPointer>
#include <QTranslator>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>
#include <memory>

class QJSEngine;
class QQmlEngine;

namespace lv {

class KeyValueStore;

// UI language: Russian by default, Uzbek (Latin) and English. Texts are
// English in the sources (tr/qsTr) and translated with the standard Qt
// pipeline: lupdate → i18n/logviewer_<code>.ts → .qm compiled into the app.
// Switching at runtime reloads the translator and retranslates QML.
class Language : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QString code READ code WRITE setCode NOTIFY codeChanged)
    Q_PROPERTY(QVariantList languages READ languages CONSTANT)

public:
    static constexpr const char* kDefaultCode = "ru";

    explicit Language(KeyValueStore& settings, QObject* parent = nullptr);
    ~Language() override;

    static void setInstance(Language* language);
    static Language* instance();
    static Language* create(QQmlEngine* engine, QJSEngine*);

    // In display order: code, name (in its own language), englishName and a
    // sample label in that language.
    QVariantList languages() const;
    static QStringList supportedCodes();

    QString code() const { return m_code; }
    // Installs the translator for `code` (unknown codes fall back to the
    // default), sets the default QLocale, persists the choice and
    // retranslates the attached engine.
    void setCode(const QString& code);

    // Applies the stored (or default) language; call before loading QML.
    void apply();
    // Engine to retranslate on changes (set by the singleton factory or the app).
    void attachEngine(QQmlEngine* engine) { m_engine = engine; }

signals:
    void codeChanged();

private:
    bool install(const QString& code);

    KeyValueStore& m_settings;
    QString m_code;
    std::unique_ptr<QTranslator> m_translator;
    QPointer<QQmlEngine> m_engine;
};

} // namespace lv
