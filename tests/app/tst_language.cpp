// Language: Russian by default, runtime switching through the embedded .qm
// files, persistence, fallback for unknown codes and QML retranslation.
#include <QCoreApplication>
#include <QLocale>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QSignalSpy>
#include <QTest>

#include "app/AppServices.h"
#include "app/Language.h"
#include "app/Session.h"
#include "support/FakeHttp.h"
#include "core/storage/KeyValueStore.h"

using namespace lv;

namespace {
QString retry() { return QCoreApplication::translate("ErrorInfo", "Retry"); }
}

class TestLanguage : public QObject {
    Q_OBJECT

private slots:
    void defaultsToRussian()
    {
        MemoryStore kv;
        Language language(kv);
        language.apply();
        QCOMPARE(language.code(), "ru");
        QCOMPARE(retry(), "Повторить");
        QCOMPARE(QLocale().language(), QLocale::Russian);
        QCOMPARE(kv.value("ui/language").toString(), "ru");
    }

    void restoresStoredChoice()
    {
        MemoryStore kv;
        kv.setValue("ui/language", "uz");
        Language language(kv);
        language.apply();
        QCOMPARE(language.code(), "uz");
        QCOMPARE(retry(), "Qayta urinish");
        QCOMPARE(QLocale().language(), QLocale::Uzbek);
        QCOMPARE(QLocale().script(), QLocale::LatinScript);
    }

    void switchesAndPersists()
    {
        MemoryStore kv;
        Language language(kv);
        language.apply();
        QSignalSpy changed(&language, &Language::codeChanged);

        language.setCode("en");
        QCOMPARE(retry(), "Retry");
        QCOMPARE(QLocale().language(), QLocale::English);
        QCOMPARE(kv.value("ui/language").toString(), "en");

        language.setCode("uz");
        QCOMPARE(retry(), "Qayta urinish");
        language.setCode("uz");
        QCOMPARE(changed.count(), 2);
    }

    void unknownCodeFallsBackToRussian()
    {
        MemoryStore kv;
        kv.setValue("ui/language", "de");
        Language language(kv);
        language.apply();
        QCOMPARE(language.code(), "ru");
        QCOMPARE(kv.value("ui/language").toString(), "ru");
    }

    void pluralFormsFollowTheLanguage()
    {
        MemoryStore kv;
        Language language(kv);
        language.apply();
        auto days = [](int n) { return QCoreApplication::translate("Presenters", "Last %n day(s)", nullptr, n); };
        QCOMPARE(days(1), "Последний 1 день");
        QCOMPARE(days(3), "Последние 3 дня");
        QCOMPARE(days(5), "Последние 5 дней");
        language.setCode("en");
        QCOMPARE(days(1), "Last 1 day");
        QCOMPARE(days(5), "Last 5 days");
    }

    void listsLanguagesInDisplayOrder()
    {
        MemoryStore kv;
        Language language(kv);
        const QVariantList list = language.languages();
        QCOMPARE(list.size(), 3);
        QCOMPARE(list[0].toMap()["code"].toString(), "ru");
        QCOMPARE(list[1].toMap()["code"].toString(), "uz");
        QCOMPARE(list[2].toMap()["code"].toString(), "en");
        QCOMPARE(list[1].toMap()["name"].toString(), "Oʻzbekcha");
    }

    void destructorRemovesTranslator()
    {
        MemoryStore kv;
        {
            Language language(kv);
            language.apply();
            QCOMPARE(retry(), "Повторить");
        }
        QCOMPARE(retry(), "Retry");
    }

    void sessionRebuildsItsTexts()
    {
        lvtest::FakeHttpClient http;
        MemoryStore kv;
        MemorySecretStore secrets;
        AppServices services(http, kv, secrets, makeInlineParseExecutor());
        Language language(kv);
        language.apply();
        Session session(services);
        QObject::connect(&language, &Language::codeChanged, &session, &Session::retranslate);
        session.start();   // nothing configured
        QCOMPARE(session.error().title, "Подключите Grafana");
        QCOMPARE(session.timeRangeLabel(), "Последний 1 час");
        QSignalSpy errorChanged(&session, &Session::errorChanged);
        QSignalSpy rangeChanged(&session, &Session::timeRangeChanged);
        language.setCode("en");
        QCOMPARE(session.error().title, "Connect to Grafana");
        QCOMPARE(session.error().primaryLabel, "Settings");
        QCOMPARE(session.timeRangeLabel(), "Last 1 hour");
        QCOMPARE(errorChanged.count(), 1);
        QCOMPARE(rangeChanged.count(), 1);
    }

    void languagesCarrySamples()
    {
        MemoryStore kv;
        Language language(kv);
        const QVariantList list = language.languages();
        QVERIFY(list[0].toMap()["sample"].toString().startsWith("Последний 1 час · "));
        QVERIFY(list[1].toMap()["sample"].toString().startsWith("Oxirgi 1 soat · "));
        QVERIFY(list[2].toMap()["sample"].toString().startsWith("Last 1 hour · "));
        QCOMPARE(list[1].toMap()["englishName"].toString(), "Uzbek (Latin)");
    }

    void retranslatesQml()
    {
        MemoryStore kv;
        Language language(kv);
        QQmlEngine engine;
        language.attachEngine(&engine);
        language.apply();

        // qsTr() takes its context from the file name, so this file
        // translates in the "ErrorInfo" context.
        QQmlComponent component(&engine);
        component.setData("import QtQml\nQtObject { property string label: qsTr(\"Retry\") }",
                          QUrl("qrc:/ErrorInfo.qml"));
        std::unique_ptr<QObject> root(component.create());
        QVERIFY2(root, qPrintable(component.errorString()));
        QCOMPARE(root->property("label").toString(), "Повторить");

        language.setCode("uz");
        QCOMPARE(root->property("label").toString(), "Qayta urinish");
        language.setCode("en");
        QCOMPARE(root->property("label").toString(), "Retry");
    }
};

QTEST_GUILESS_MAIN(TestLanguage)
#include "tst_language.moc"
