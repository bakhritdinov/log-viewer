// Runs the desktop design against a fake Grafana (see support/UiHarness.h).
#include <QtQml/qqmlextensionplugin.h>
#include <QtQuickTest>

#include "support/UiHarness.h"

Q_IMPORT_QML_PLUGIN(LogViewer_AppPlugin)
Q_IMPORT_QML_PLUGIN(LogViewer_UiPlugin)
Q_IMPORT_QML_PLUGIN(LogViewer_DesktopPlugin)

using namespace lvtest;

QUICK_TEST_MAIN_WITH_SETUP(ui_desktop, Setup)
