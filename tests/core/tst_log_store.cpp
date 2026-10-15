#include <QTest>

#include "core/features/LogStore.h"

using namespace lv;

namespace {
const QDateTime kT0 = QDateTime::fromString("2026-10-15T12:00:00Z", Qt::ISODate);

LogEntry entry(qint64 offsetMs, const QString& msg, Level level = Level::Info, QVariantMap fields = {})
{
    return { kT0.addMSecs(offsetMs), msg, std::move(fields), level };
}

QStringList messages(const LogEntries& list)
{
    QStringList out;
    for (const LogEntry& e : list) out << e.message;
    return out;
}
} // namespace

class TestLogStore : public QObject {
    Q_OBJECT

private slots:
    void addKeepsNewestFirst()
    {
        LogStore s;
        QCOMPARE(s.add({ entry(0, "a"), entry(2000, "c"), entry(1000, "b") }), 3);
        QCOMPARE(messages(s.all()), (QStringList{ "c", "b", "a" }));
        QCOMPARE(s.newestMs(), kT0.toMSecsSinceEpoch() + 2000);
        QCOMPARE(s.oldestMs(), kT0.toMSecsSinceEpoch());
        QCOMPARE(s.add({ entry(1500, "x") }), 1);
        QCOMPARE(messages(s.all()), (QStringList{ "c", "x", "b", "a" }));
    }

    void deduplicatesAcrossBatches()
    {
        // Intended change #8: overlapping batches no longer duplicate entries.
        LogStore s;
        s.add({ entry(1000, "same", Level::Info, { { "pod", "p1" } }) });
        QCOMPARE(s.add({ entry(1000, "same", Level::Info, { { "pod", "p1" } }) }), 0);
        QCOMPARE(s.size(), 1);
        // Same time and message but different fields is a different entry.
        QCOMPARE(s.add({ entry(1000, "same", Level::Info, { { "pod", "p2" } }) }), 1);
        // Duplicates inside one batch are dropped too.
        QCOMPARE(s.add({ entry(5, "d"), entry(5, "d") }), 1);
    }

    void entryKeyIsContentBased()
    {
        QCOMPARE(entryKey(entry(1, "m", Level::Info, { { "a", 1 } })), entryKey(entry(1, "m", Level::Info, { { "a", 1 } })));
        QVERIFY(entryKey(entry(1, "m")) != entryKey(entry(2, "m")));
        QVERIFY(entryKey(entry(1, "m")) != entryKey(entry(1, "n")));
        QVERIFY(entryKey(entry(1, "m", Level::Info, { { "a", 1 } })) != entryKey(entry(1, "m", Level::Info, { { "a", 2 } })));
    }

    void capacityEvictsOldest()
    {
        LogStore s;
        s.addCapped({ entry(0, "a"), entry(1000, "b"), entry(2000, "c") }, 2);
        QCOMPARE(messages(s.all()), (QStringList{ "c", "b" }));
        // An evicted entry is forgotten, so it counts as new if it comes back.
        QCOMPARE(s.addCapped({ entry(0, "a") }, 3), 1);
    }

    void filterByWindowAndLevel()
    {
        LogStore s;
        s.add({ entry(0, "e0", Level::Error), entry(30000, "i30"), entry(60000, "e60", Level::Error) });
        const qint64 t0 = kT0.toMSecsSinceEpoch();
        s.setFilter({ t0, t0 + 60000, Level::Error });   // [from, to): e60 excluded
        QCOMPARE(messages(s.visible()), QStringList{ "e0" });
        QCOMPARE(s.size(), 3);
        s.setFilter({ 0, 0, Level::Error });               // level only
        QCOMPARE(messages(s.visible()), (QStringList{ "e60", "e0" }));
        // New entries respect the active filter.
        s.add({ entry(90000, "e90", Level::Error), entry(91000, "i91") });
        QCOMPARE(messages(s.visible()), (QStringList{ "e90", "e60", "e0" }));
        s.clearFilter();
        QVERIFY(!s.filter().isActive());
        QCOMPARE(s.visible().size(), 5);
    }

    void paging()
    {
        LogStore s;
        LogEntries list;
        for (int i = 0; i < 250; ++i) list << entry(i * 1000, QString::number(i));
        s.add(list);
        QCOMPARE(s.pageCount(100), 3);
        QCOMPARE(s.page(0, 100).first().message, "249");
        QCOMPARE(s.page(2, 100).size(), 50);
        QCOMPARE(s.page(2, 100).first().message, "49");
        // Intended change #9: out-of-range pages clamp to the last page.
        QCOMPARE(s.clampPage(7, 100), 2);
        QCOMPARE(s.page(7, 100).first().message, "49");
        QCOMPARE(s.clampPage(-3, 100), 0);
        QCOMPARE(s.page(0, 0).size(), 250);
        QCOMPARE(LogStore().pageCount(100), 1);
        QVERIFY(LogStore().page(0, 100).isEmpty());
    }

    void pagingFollowsFilter()
    {
        LogStore s;
        LogEntries list;
        for (int i = 0; i < 150; ++i) list << entry(i, QString::number(i), i % 2 ? Level::Error : Level::Info);
        s.add(list);
        s.setFilter({ 0, 0, Level::Error });
        QCOMPARE(s.pageCount(100), 1);
        QCOMPARE(s.page(0, 100).size(), 75);
    }

    void clear()
    {
        LogStore s;
        s.add({ entry(0, "a") });
        s.clear();
        QCOMPARE(s.size(), 0);
        QCOMPARE(s.oldestMs(), 0);
        QCOMPARE(s.add({ entry(0, "a") }), 1);   // keys were forgotten
    }
};

QTEST_GUILESS_MAIN(TestLogStore)
#include "tst_log_store.moc"
