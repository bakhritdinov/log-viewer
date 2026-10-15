// The LogViewer.App module imports in QML and exposes the singleton, its
// models and the creatable editor — the contract the designs build on.
#include <QQmlComponent>
#include <QQmlEngine>
#include <QTest>
#include <QtQml/qqmlextensionplugin.h>

#include "app/AppServices.h"
#include "app/Session.h"
#include "support/FakeHttp.h"

Q_IMPORT_QML_PLUGIN(LogViewer_AppPlugin)

using namespace lv;
using namespace lvtest;

class TestQmlModule : public QObject {
    Q_OBJECT

private slots:
    void importsAndBinds()
    {
        FakeHttpClient http;
        MemoryStore kv;
        MemorySecretStore secrets;
        AppServices services(http, kv, secrets, makeInlineParseExecutor());
        Session session(services);
        Session::setInstance(&session);

        QQmlEngine engine;
        QQmlComponent component(&engine);
        component.setData(R"(
            import QtQml
            import LogViewer.App
            QtObject {
                property string env: Session.environmentName
                property int environments: Session.environments.count
                property string firstEnv: Session.environments.get(0).name
                property bool setup: Session.needsSetup
                property int errorKind: Session.error.kind
                property string search: Session.searchText
                property int chips: Session.chips.count
                property bool focusActive: Session.focus.active
                property bool liveRunning: Session.live.running
                property int pageSize: Session.logs.pageSize
                property var editor: EnvironmentEditor { }
                property int editorColors: editor.colors.length
                property int action: ErrorInfo.OpenSettings
                Component.onCompleted: Session.searchText = "timeout AND level:error"
            }
        )", QUrl("qrc:/test.qml"));
        std::unique_ptr<QObject> root(component.create());
        QVERIFY2(root, qPrintable(component.errorString()));
        QCOMPARE(root->property("env").toString(), "DEV");
        QCOMPARE(root->property("environments").toInt(), 2);
        QCOMPARE(root->property("firstEnv").toString(), "DEV");
        QCOMPARE(root->property("search").toString(), "timeout AND level:error");
        QCOMPARE(root->property("chips").toInt(), 2);
        QCOMPARE(root->property("focusActive").toBool(), false);
        QCOMPARE(root->property("pageSize").toInt(), 100);
        QCOMPARE(root->property("editorColors").toInt(), 5);
        QCOMPARE(root->property("action").toInt(), int(ErrorInfo::Action::OpenSettings));

        session.start();   // not configured
        QCOMPARE(root->property("setup").toBool(), true);
        QCOMPARE(root->property("errorKind").toInt(), int(ErrorInfo::Kind::NotConfigured));
        Session::setInstance(nullptr);
    }
};

QTEST_GUILESS_MAIN(TestQmlModule)
#include "tst_qml_module.moc"
