#include "FifoChannels.h"

FifoChannels::FifoChannels(QObject* parent) : QObject(parent) {
    // Register every FIFO group here. To add a new one (e.g. by client_id)
    // copy the block below and replace fields.
    {
        FifoGroup g;
        g.id                = QStringLiteral("contract");
        g.label             = QStringLiteral("contract_update_state");
        g.searchField       = QStringLiteral("contract_id");
        g.searchPlaceholder = QStringLiteral("Contract ID (e.g. 1234567)");
        g.channels = {
            { QStringLiteral("contract_update_state_errors"), QString() },
            { QStringLiteral("contract_update_state"),
              QStringLiteral("contract_update_state_errors") },
        };
        m_groups << g;
    }
    // Example template for a future group:
    // {
    //     FifoGroup g;
    //     g.id = "client";
    //     g.label = "Client";
    //     g.searchField = "client_id";
    //     g.searchPlaceholder = "Client ID";
    //     g.channels = {
    //         { "client_<something>_errors", "" },
    //         { "client_<something>",        "client_<something>_errors" },
    //     };
    //     m_groups << g;
    // }
}

QVariantList FifoChannels::groups() const {
    QVariantList out;
    out.reserve(m_groups.size());
    for (const auto& g : m_groups) {
        QVariantList chans;
        chans.reserve(g.channels.size());
        for (const auto& c : g.channels) {
            QVariantMap m;
            m["name"]      = c.name;
            m["rerouteTo"] = c.rerouteTo;
            chans << m;
        }
        QVariantMap gm;
        gm["id"]                = g.id;
        gm["label"]             = g.label;
        gm["searchField"]       = g.searchField;
        gm["searchPlaceholder"] = g.searchPlaceholder;
        gm["channels"]          = chans;
        out << gm;
    }
    return out;
}

bool FifoChannels::isFifo(const QString& channel) const {
    for (const auto& g : m_groups)
        for (const auto& c : g.channels)
            if (c.name == channel) return true;
    return false;
}

QString FifoChannels::rerouteFor(const QString& channel) const {
    for (const auto& g : m_groups)
        for (const auto& c : g.channels)
            if (c.name == channel) return c.rerouteTo;
    return {};
}

QString FifoChannels::groupIdFor(const QString& channel) const {
    for (const auto& g : m_groups)
        for (const auto& c : g.channels)
            if (c.name == channel) return g.id;
    return {};
}

QStringList FifoChannels::allChannels() const {
    QStringList out;
    for (const auto& g : m_groups)
        for (const auto& c : g.channels) out << c.name;
    return out;
}

const FifoGroup* FifoChannels::findGroup(const QString& id) const {
    for (const auto& g : m_groups) if (g.id == id) return &g;
    return nullptr;
}
