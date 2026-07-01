# SPDX-FileCopyrightText: 2026 Deskflow Developers
# SPDX-License-Identifier: MIT
# Runs via CPACK_PRE_BUILD_SCRIPTS: seal the fully-staged .app as one unit,
# right before the DMG is built. macdeployqt only signs files individually, so
# the outer bundle seal fails `codesign --verify --deep --strict` and macOS TCC
# (Accessibility/Input Monitoring) won't recognize the installed app. This runs
# after everything else has touched the staging tree, so the seal sticks.
# The .app sits under a CPack component-group dir (e.g. ALL_IN_ONE/), not at the
# staging root -- glob both the root and one level down to catch either layout.
file(GLOB _apps
  "${CPACK_TEMPORARY_INSTALL_DIRECTORY}/*.app"
  "${CPACK_TEMPORARY_INSTALL_DIRECTORY}/*/*.app"
  "${CPACK_TEMPORARY_DIRECTORY}/*.app"
  "${CPACK_TEMPORARY_DIRECTORY}/*/*.app")
if(NOT _apps)
  message(FATAL_ERROR "resign.cmake: no .app found in CPack staging "
    "(CPACK_TEMPORARY_INSTALL_DIRECTORY='${CPACK_TEMPORARY_INSTALL_DIRECTORY}', "
    "CPACK_TEMPORARY_DIRECTORY='${CPACK_TEMPORARY_DIRECTORY}') -- bundle would ship unsealed")
endif()
list(REMOVE_DUPLICATES _apps)
foreach(_app ${_apps})
  # Fail the build if any executable still links a non-bundled (Homebrew/local)
  # Qt or dylib -- such a bundle runs on this build machine but crashes on users'
  # machines that lack those libs. Catches a broken macdeployqt -executable= step.
  file(GLOB _bins "${_app}/Contents/MacOS/*")
  foreach(_bin ${_bins})
    execute_process(COMMAND otool -L "${_bin}" OUTPUT_VARIABLE _libs)
    if(_libs MATCHES "/opt/homebrew|/usr/local/(Cellar|opt)")
      message(FATAL_ERROR "resign.cmake: ${_bin} links non-bundled libs "
        "(bundle is not self-contained):\n${_libs}")
    endif()
  endforeach()
  message(STATUS "Ad-hoc re-signing bundle: ${_app}")
  execute_process(COMMAND codesign --force --deep --sign - "${_app}"
    COMMAND_ERROR_IS_FATAL ANY)
endforeach()
