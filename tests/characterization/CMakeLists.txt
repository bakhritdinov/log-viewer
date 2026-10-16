# Characterization: the golden files in tests/fixtures/characterization capture
# what the pre-rewrite query code did (generated from its git revision, see the
# README there); the core tests check the new code against them. This test
# keeps the files themselves well-formed.
logviewer_add_test(tst_golden_fixtures
    SOURCES tst_golden_fixtures.cpp
    LIBS Qt6::Core)
