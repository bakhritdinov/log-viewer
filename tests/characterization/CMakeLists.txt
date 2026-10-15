# Characterization tests: pin down the behaviour of the pre-rewrite code so the
# new core can be checked against it. They test legacy sources directly and are
# removed together with those sources at the end of the rewrite.
logviewer_add_test(tst_legacy_logmodel
    SOURCES tst_legacy_logmodel.cpp
    LIBS LogViewerLogs)

logviewer_add_test(tst_golden_fixtures
    SOURCES tst_golden_fixtures.cpp
    LIBS Qt6::Core)
