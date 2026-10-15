// Runs the mobile design against a fake Grafana (see support/UiHarness.h).
#include <QtQml/qqmlextensionplugin.h>
#include <QtQuickTest>

#include "app/Preferences.h"
#include "support/UiHarness.h"

Q_IMPORT_QML_PLUGIN(LogViewer_AppPlugin)
Q_IMPORT_QML_PLUGIN(LogViewer_UiPlugin)
Q_IMPORT_QML_PLUGIN(LogViewer_MobilePlugin)

using namespace lvtest;

// The phone's preference defaults, as the app sets them in main.
static const bool phoneDefaults = [] {
    lv::Preferences::setDefaults(lv::Preferences::Defaults::phone());
    return true;
}();

QUICK_TEST_MAIN_WITH_SETUP(ui_mobile, Setup)
