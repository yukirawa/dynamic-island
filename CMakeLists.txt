cmake_minimum_required(VERSION 3.24)
project(dynamic-island LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Choose the type of build (Debug, Release, RelWithDebInfo, MinSizeRel)." FORCE)
endif()

option(DYNAMIC_ISLAND_NATIVE "Optimize specifically for the build machine (-march=native -mtune=native)" OFF)
option(DYNAMIC_ISLAND_LTO "Enable Link Time Optimization (LTO/IPO) for Release builds" ON)

include(CheckCXXCompilerFlag)
include(CheckLinkerFlag)
include(CheckIPOSupported)

# Release optimization flags. CMake already supplies -O3 -DNDEBUG on GCC/Clang
# in CMAKE_CXX_FLAGS_RELEASE, so only add them if missing to avoid duplicates.
if(NOT CMAKE_CXX_FLAGS_RELEASE MATCHES "(^| )-O([0-9s]|fast|g)( |$)")
    add_compile_options($<$<CONFIG:Release>:-O3>)
endif()
if(NOT CMAKE_CXX_FLAGS_RELEASE MATCHES "(^| )-DNDEBUG( |$)")
    add_compile_definitions($<$<CONFIG:Release>:NDEBUG>)
endif()

foreach(_flag IN ITEMS -fomit-frame-pointer -fno-plt -ffunction-sections -fdata-sections)
    string(MAKE_C_IDENTIFIER "CXX_HAS${_flag}" _var)
    check_cxx_compiler_flag("${_flag}" "${_var}")
    if(${_var})
        add_compile_options($<$<CONFIG:Release>:${_flag}>)
    endif()
endforeach()

check_linker_flag(CXX "-Wl,--gc-sections" LINKER_HAS_GC_SECTIONS)
if(LINKER_HAS_GC_SECTIONS)
    add_link_options($<$<CONFIG:Release>:-Wl,--gc-sections>)
endif()

if(DYNAMIC_ISLAND_NATIVE)
    check_cxx_compiler_flag("-march=native" CXX_HAS_MARCH_NATIVE)
    if(CXX_HAS_MARCH_NATIVE)
        add_compile_options($<$<CONFIG:Release>:-march=native>)
    endif()
    check_cxx_compiler_flag("-mtune=native" CXX_HAS_MTUNE_NATIVE)
    if(CXX_HAS_MTUNE_NATIVE)
        add_compile_options($<$<CONFIG:Release>:-mtune=native>)
    endif()
endif()

if(DYNAMIC_ISLAND_LTO)
    check_ipo_supported(RESULT DYNAMIC_ISLAND_IPO_SUPPORTED OUTPUT DYNAMIC_ISLAND_IPO_ERROR)
    if(DYNAMIC_ISLAND_IPO_SUPPORTED)
        set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE ON)
    else()
        message(STATUS "LTO/IPO not supported: ${DYNAMIC_ISLAND_IPO_ERROR}")
    endif()
endif()

message(STATUS "Dynamic Island build type: ${CMAKE_BUILD_TYPE}, native: ${DYNAMIC_ISLAND_NATIVE}, LTO: ${DYNAMIC_ISLAND_LTO}")

find_package(Qt6 6.8 REQUIRED COMPONENTS Gui Quick QuickTest DBus Network ShaderTools)
find_package(KF6CalendarCore REQUIRED)
find_package(KF6GuiAddons REQUIRED)
find_package(KF6Config REQUIRED)
find_package(KF6IdleTime REQUIRED)
find_package(KF6GlobalAccel REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(DBUS1 REQUIRED IMPORTED_TARGET dbus-1)
find_package(LayerShellQt REQUIRED)
pkg_check_modules(PULSE IMPORTED_TARGET libpulse)
qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(dynamic-island src/main.cpp src/audiospectrum.h src/audiospectrum.cpp)
qt_add_qml_module(dynamic-island
    URI Island
    SOURCES src/inputregion.h src/inputregion.cpp src/notifier.h src/notifier.cpp src/systemstatus.h src/systemstatus.cpp src/appconfig.h src/appconfig.cpp src/calendarsource.h src/calendarsource.cpp src/clipboardhistory.h src/clipboardhistory.cpp src/notesstore.h src/notesstore.cpp src/notificationwatcher.h src/notificationwatcher.cpp src/notificationlog.h src/notificationlog.cpp src/bluetoothwatcher.h src/bluetoothwatcher.cpp src/plasmasettings.h src/plasmasettings.cpp src/camerawatcher.h src/camerawatcher.cpp src/capslockwatcher.h src/capslockwatcher.cpp src/updateswatcher.h src/updateswatcher.cpp src/jobwatcher.h src/jobwatcher.cpp src/fullscreenwatcher.h src/fullscreenwatcher.cpp src/panelshortcut.h src/panelshortcut.cpp
    QML_FILES qml/Main.qml qml/logic.js qml/PlayerSource.qml qml/MprisPlayers.qml qml/Bars.qml qml/Island.qml qml/ControlButton.qml qml/CoverArt.qml qml/MusicPlayer.qml qml/HomePanel.qml qml/TimerModel.qml qml/TimerCard.qml qml/QuickButtons.qml qml/weather.js qml/WeatherSource.qml qml/WeatherCard.qml qml/MonthCalendar.qml qml/UpNext.qml qml/MusicCard.qml qml/Prefs.qml qml/Tape.qml qml/TimerTab.qml qml/Pill.qml qml/PixelCat.qml qml/IdleArt.qml qml/VolumeSlider.qml qml/Mixer.qml qml/SoundSource.qml qml/SettingsWindow.qml qml/ClipboardTab.qml qml/NotesTab.qml qml/AlertView.qml qml/ShelfTab.qml qml/QuickLinksTab.qml qml/ColorTab.qml qml/JobsModel.qml qml/NotificationHistory.qml qml/NotificationsTab.qml
    qml/ui/Icon.qml qml/ui/Button.qml qml/ui/CheckBox.qml qml/ui/RadioButton.qml qml/ui/Switch.qml
    qml/ui/Label.qml qml/ui/TextField.qml qml/ui/TextArea.qml qml/ui/ComboBox.qml qml/ui/Slider.qml
    qml/ui/ToolTip.qml qml/ui/ToolButton.qml qml/ui/ScrollView.qml qml/ui/Separator.qml
    qml/ui/Heading.qml qml/ui/ItemDelegate.qml
)
# Japanese translations. lupdate and lrelease are run by hand (translations/
# README explains), and the compiled .qm files are embedded so the binary
# works both from the build directory and after a system install.
qt_add_resources(dynamic-island "i18n" PREFIX "/i18n" FILES translations/dynamic-island-ja.qm)
target_include_directories(dynamic-island PRIVATE src)
qt_add_resources(dynamic-island "kwin" PREFIX "/" FILES data/kwin/fullscreen.js)
qt_add_shaders(dynamic-island "shaders" PREFIX "/" FILES shaders/aurora.frag shaders/wave.frag shaders/fireflies.frag)
target_link_libraries(dynamic-island PRIVATE Qt6::Quick Qt6::DBus Qt6::Network KF6::CalendarCore KF6::GuiAddons KF6::ConfigCore KF6::IdleTime KF6::GlobalAccel PkgConfig::DBUS1 PkgConfig::PULSE LayerShellQt::Interface)

include(GNUInstallDirs)
install(TARGETS dynamic-island)

enable_testing()
find_program(QMLTESTRUNNER qmltestrunner HINTS ${QT6_INSTALL_PREFIX}/${QT6_INSTALL_BINS} /usr/lib/qt6/bin REQUIRED)
add_test(NAME qml COMMAND ${QMLTESTRUNNER} -input ${CMAKE_SOURCE_DIR}/tests -import ${CMAKE_BINARY_DIR})
# Hidden window: the tests simulate the mouse, and a visible one pops up on screen and catches the real pointer.
# C locale: the tests assert on the English source strings, so they must not pick up a system translation.
set_tests_properties(qml PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen;LANG=C;LC_ALL=C;DYNAMIC_ISLAND_TEST_EN=1")

configure_file(data/dynamic-island.desktop.in dynamic-island.desktop @ONLY)
install(FILES ${CMAKE_BINARY_DIR}/dynamic-island.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)

find_package(Qt6 REQUIRED COMPONENTS Test)
qt_add_executable(tst_systemstatus tests/cpp/tst_systemstatus.cpp src/systemstatus.cpp src/systemstatus.h)
target_include_directories(tst_systemstatus PRIVATE src)
target_link_libraries(tst_systemstatus PRIVATE Qt6::Test Qt6::Gui Qt6::DBus Qt6::Qml KF6::IdleTime)
add_test(NAME cpp_systemstatus COMMAND tst_systemstatus)

qt_add_executable(tst_calendar tests/cpp/tst_calendar.cpp src/calendarsource.cpp src/calendarsource.h)
target_include_directories(tst_calendar PRIVATE src)
target_link_libraries(tst_calendar PRIVATE Qt6::Test Qt6::Network Qt6::Qml KF6::CalendarCore)
add_test(NAME cpp_calendar COMMAND tst_calendar)

qt_add_executable(tst_appconfig tests/cpp/tst_appconfig.cpp src/appconfig.cpp src/appconfig.h)
target_include_directories(tst_appconfig PRIVATE src)
target_link_libraries(tst_appconfig PRIVATE Qt6::Test Qt6::Qml)
add_test(NAME cpp_appconfig COMMAND tst_appconfig)

qt_add_executable(tst_clipboard tests/cpp/tst_clipboard.cpp src/clipboardhistory.cpp src/clipboardhistory.h)
target_include_directories(tst_clipboard PRIVATE src)
target_link_libraries(tst_clipboard PRIVATE Qt6::Test Qt6::Gui Qt6::Qml KF6::GuiAddons)
add_test(NAME cpp_clipboard COMMAND tst_clipboard)

qt_add_executable(tst_notes tests/cpp/tst_notes.cpp src/notesstore.cpp src/notesstore.h)
target_include_directories(tst_notes PRIVATE src)
target_link_libraries(tst_notes PRIVATE Qt6::Test Qt6::Qml)
add_test(NAME cpp_notes COMMAND tst_notes)

qt_add_executable(tst_history tests/cpp/tst_history.cpp src/notificationlog.cpp src/notificationlog.h)
target_include_directories(tst_history PRIVATE src)
target_link_libraries(tst_history PRIVATE Qt6::Test Qt6::Qml)
add_test(NAME cpp_history COMMAND tst_history)

qt_add_executable(tst_watchers tests/cpp/tst_watchers.cpp src/notificationwatcher.cpp src/notificationwatcher.h src/jobwatcher.cpp src/jobwatcher.h src/bluetoothwatcher.cpp src/bluetoothwatcher.h
    src/plasmasettings.cpp src/plasmasettings.h src/camerawatcher.cpp src/camerawatcher.h src/capslockwatcher.cpp src/capslockwatcher.h src/updateswatcher.cpp src/updateswatcher.h src/fullscreenwatcher.cpp src/fullscreenwatcher.h src/inputregion.cpp src/inputregion.h)
target_include_directories(tst_watchers PRIVATE src)
target_link_libraries(tst_watchers PRIVATE Qt6::Test Qt6::Gui Qt6::DBus Qt6::Qml KF6::ConfigCore PkgConfig::DBUS1 LayerShellQt::Interface)
add_test(NAME cpp_watchers COMMAND tst_watchers)

# The Japanese catalog ships as the i18n resource in the main binary; embed a
# copy here so the check always runs against the same data lrelease produced.
qt_add_executable(tst_translation tests/cpp/tst_translation.cpp)
qt_add_resources(tst_translation "i18n" PREFIX "/i18n" FILES translations/dynamic-island-ja.qm)
target_include_directories(tst_translation PRIVATE src)
target_link_libraries(tst_translation PRIVATE Qt6::Test Qt6::Gui Qt6::Qml)
add_test(NAME cpp_translation COMMAND tst_translation)
set_tests_properties(cpp_watchers PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen;LANG=C;LC_ALL=C")
