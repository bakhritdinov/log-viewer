# Writes sw.js from sw.js.in (cmake -DIN=… -DOUT=… -DVERSION=… -P stamp_sw.cmake).
# The service worker's cache name carries the version and the build time, so
# every build is a new cache: the page sees a waiting worker and offers
# "A new version is available · Update".
if(NOT IN OR NOT OUT OR NOT VERSION)
    message(FATAL_ERROR "stamp_sw.cmake needs -DIN=<sw.js.in> -DOUT=<sw.js> -DVERSION=<x.y.z>")
endif()
string(TIMESTAMP LOGVIEWER_PWA_BUILD "%Y%m%d%H%M%S" UTC)
set(LOGVIEWER_PWA_VERSION "${VERSION}-${LOGVIEWER_PWA_BUILD}")
configure_file("${IN}" "${OUT}" @ONLY)
