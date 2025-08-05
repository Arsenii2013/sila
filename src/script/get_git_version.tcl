namespace eval GitVersionScript {

set hash [exec git rev-parse --short=8 HEAD]

set versionWildcards [list "\[0-9\]" "\[1-9\]\[0-9\]"]
set maxMajor 0
set maxMinor 0

foreach majorWildcard $versionWildcards {
    foreach minorWildcard $versionWildcards {
        set err [catch {exec -ignorestderr git describe --tags --abbrev=0 --match "v$majorWildcard\.$minorWildcard" 2>/dev/null} version ]
        if {!$err && [scan $version "v%d.%d" major minor] == 2} {
            if {$major > $maxMajor} {
                set maxMajor $major
                set maxMinor $minor
            } elseif {$minor > $maxMinor} {
                set maxMinor $minor
            }
        }
    }
}

}

set_property verilog_define "GIT_HASH='h$GitVersionScript::hash
                             GIT_VERSION_MAJOR=$GitVersionScript::maxMajor
                             GIT_VERSION_MINOR=$GitVersionScript::maxMinor" [current_fileset]
