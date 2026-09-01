# SPDX-FileCopyrightText: (C) 2024 Chris Rizzitello <sithlord48@gmail.com>
# SPDX-License-Identifier: MIT

# HACK This is set when the files is included so its the real path
# calling CMAKE_CURRENT_LIST_DIR after include would return the wrong scope var
set(MY_DIR ${CMAKE_CURRENT_LIST_DIR})
set(OSX_BUNDLE ${BUILD_OSX_BUNDLE})

set(OS_STRING "macos-${BUILD_ARCHITECTURE}")

if (OSX_BUNDLE)
  set(_codesign_identity "-")
  if (APPLE_CODESIGN_DEV)
    set(_codesign_identity "${APPLE_CODESIGN_DEV}")
  endif()
  # macdeployqt only fixes main app; core keeps absolute Qt paths without -executable.
  # DevID: hardened runtime required for notarization. Ad-hoc: must NOT use
  # hardened runtime — otherwise library validation fails (dyld: different Team IDs)
  # because ad-hoc has no TeamID and no entitlements to disable validation.
  if (APPLE_CODESIGN_DEV)
    install(CODE "execute_process(COMMAND
      ${DEPLOYQT}
      \"\${CMAKE_INSTALL_PREFIX}/${CMAKE_PROJECT_PROPER_NAME}.app\"
      \"-executable=\${CMAKE_INSTALL_PREFIX}/${CMAKE_PROJECT_PROPER_NAME}.app/Contents/MacOS/${CMAKE_PROJECT_NAME}-core\"
      -hardened-runtime -timestamp \"-codesign=${_codesign_identity}\"
    )")
  else()
    install(CODE "execute_process(COMMAND
      ${DEPLOYQT}
      \"\${CMAKE_INSTALL_PREFIX}/${CMAKE_PROJECT_PROPER_NAME}.app\"
      \"-executable=\${CMAKE_INSTALL_PREFIX}/${CMAKE_PROJECT_PROPER_NAME}.app/Contents/MacOS/${CMAKE_PROJECT_NAME}-core\"
      -timestamp \"-codesign=-\"
    )")
  endif()
  # macdeployqt signs each file individually, which leaves the outer bundle seal
  # stale (fails `codesign --deep --strict`, so macOS TCC won't recognize the
  # app). Re-seal the whole bundle as one unit after CPack has staged every file
  # (translations, strip, etc.) -- see resign.cmake.
  # Only for free ad-hoc path — official Dev ID is signed/notarized in CI
  if(NOT APPLE_CODESIGN_DEV)
    set(CPACK_PRE_BUILD_SCRIPTS "${MY_DIR}/resign.cmake")
  endif()
  set(CPACK_PACKAGE_ICON "${MY_DIR}/dmg-volume.icns")
  set(CPACK_DMG_BACKGROUND_IMAGE "${MY_DIR}/dmg-background.tiff")
  set(CPACK_DMG_DS_STORE_SETUP_SCRIPT "${MY_DIR}/generate_ds_store.applescript")
  set(CPACK_DMG_VOLUME_NAME "${CMAKE_PROJECT_PROPER_NAME}")
  set(CPACK_DMG_SLA_USE_RESOURCE_FILE_LICENSE ON)
  set(CPACK_GENERATOR "DragNDrop")
endif()
