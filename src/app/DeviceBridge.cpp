#include "app/DeviceBridge.h"

namespace lv {

void DeviceBridge::setShareHandler(ShareHandler handler)
{
    m_share = std::move(handler);
    emit changed();
}

void DeviceBridge::setFileHandlers(SaveHandler save, OpenHandler open)
{
    m_save = std::move(save);
    m_open = std::move(open);
    emit changed();
}

void DeviceBridge::share(const QString& title, const QString& url)
{
    if (m_share) m_share(title, url);
}

void DeviceBridge::saveFile(const QString& fileName, const QString& content)
{
    if (m_save) m_save(fileName, content);
}

void DeviceBridge::openFile()
{
    if (m_open) m_open();
}

} // namespace lv
