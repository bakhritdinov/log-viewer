#pragma once

#include <QHash>
#include <QList>
#include <QString>
#include <QStringView>

#include "core/query/Query.h"

namespace lv {

// field → value → number of loaded entries carrying it (the facets).
using FieldValueCounts = QHash<QString, QHash<QString, int>>;

struct Suggestion {
    enum class Kind { Field, Value };
    Kind kind = Kind::Field;
    QString field;
    QString value;      // Kind::Value only
    int count = 0;      // distinct values (Field) or occurrences (Value)
    // Search text with the part being typed replaced by this suggestion:
    // "field:" for a field, `field:"value"` for a value.
    QString completedText;
    // The filter a value suggestion stands for (to include or exclude it).
    FieldFilter filter;

    bool operator==(const Suggestion& other) const = default;
};

// Suggestions for the part currently being typed (the text after the last
// " AND "). Typing a field name suggests fields; after "field:" it suggests that
// field's values matching what follows the colon. Matching is case-insensitive;
// prefix matches rank first, then by count.
QList<Suggestion> suggest(QStringView searchText, const FieldValueCounts& facets, int limit = 8);

} // namespace lv
