// Runs the LogViewer.Ui Qt Quick tests in one UI language, taken from
// LOGVIEWER_TEST_LANGUAGE (ru by default); ctest registers one run per language.
#include <QQmlEngine>
#include <QtQml/qqmlextensionplugin.h>
#include <QtQuickTest>

#include "app/Language.h"
#include "core/storage/KeyValueStore.h"

Q_IMPORT_QML_PLUGIN(LogViewer_AppPlugin)
Q_IMPORT_QML_PLUGIN(LogViewer_UiPlugin)

class Setup : public QObject {
    Q_OBJECT

public slots:
    void applicationAvailable()
    {
        m_settings.setValue("ui/language", qEnvironmentVariable("LOGVIEWER_TEST_LANGUAGE", "ru"));
        m_language = std::make_unique<lv::Language>(m_settings);
        lv::Language::setInstance(m_language.get());
        m_language->apply();
    }
    void qmlEngineAvailable(QQmlEngine* engine) { m_language->attachEngine(engine); }
    void cleanupTestCase() { m_language.reset(); }   // before the application goes away

private:
    lv::MemoryStore m_settings;
    std::unique_ptr<lv::Language> m_language;
};

QUICK_TEST_MAIN_WITH_SETUP(ui_shared, Setup)
#include "tst_ui_shared.moc"
