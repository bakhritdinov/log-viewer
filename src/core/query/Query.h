#pragma once

#include <QList>
#include <QString>
#include <QStringList>
#include <QStringView>
#include <QVariant>

namespace lv {

// `field:"value"` condition. `regex` is `field:~"pattern"`, `exclude` is `-field:"value"`.
struct FieldFilter {
    QString field;
    QString value;
    bool regex = false;
    bool exclude = false;

    bool operator==(const FieldFilter& other) const = default;
    // Text form used in the search field: field:"value", field:~"re", -field:"value".
    QString toText() const;
};

// One part of a search: a free-text word or a field filter.
struct QueryTerm {
    enum class Kind { Word, Filter };
    Kind kind = Kind::Word;
    QString word;
    FieldFilter filter;

    bool operator==(const QueryTerm& other) const = default;
};

// Parsed search text. Syntax (parts joined by " AND ", case-insensitive):
//   word                     free-text, case-insensitive substring match
//   field:value              equality; value may be "quoted" with \" and \\ escapes
//   field:~pattern           regular expression
//   -field:value             exclusion (also -field:~pattern)
// Empty parts and a bare "*" are ignored.
class Query {
public:
    static Query parse(QStringView text);
    // Parses one part ("field:value" or a word). An empty or "*" part yields a
    // Word term with empty text, meaning "no condition".
    static QueryTerm parseTerm(QStringView part);

    const QList<QueryTerm>& terms() const { return m_terms; }
    bool isEmpty() const { return m_terms.isEmpty(); }
    // Free-text words, used for highlighting matches.
    QStringList words() const;
    QList<FieldFilter> filters() const;

    bool operator==(const Query& other) const = default;

private:
    QList<QueryTerm> m_terms;
};

// Splits search text into its raw parts (on " AND ", case-insensitive), untrimmed.
QStringList splitQueryParts(QStringView text);

// Adds `filter` to the search text, or removes it when an equivalent filter is
// already there (quoted and unquoted spellings are equivalent). Other parts keep
// their original spelling.
// A filter with an empty field or value leaves the text untouched.
QString toggleFilterInText(QStringView text, const FieldFilter& filter);

// Text of a field value as shown in filters and chips. Integers stay integers,
// fractions are kept, booleans are "true"/"false", date-times use
// "yyyy-MM-dd HH:mm:ss.zzz"; null/invalid becomes an empty string.
QString formatFieldValue(const QVariant& value);

} // namespace lv
