#!/usr/bin/tclsh8.5

# Swapspaces.tcl, copyright 2009, 2010 David N. Welton
# <davidw@dedasys.com> - http://www.dedasys.com

# This program lets you swap different virtual workspaces around by
# swapping the contents of two of them.  It requires the wmctrl
# package.

package require Tk

## global variables:

# Current list of windows
set windowlist [list]

# Current list of projects
set projectlist [dict create]

set projectfile "~/.swapspacesprojects.tcl"

# Try loading projectlist from here:
catch {
    source $projectfile
}

# Desktop list
set desktops []
foreach d [split [exec wmctrl -d] "\n"] {
    lappend desktops [lindex $d 0]
}


# desktops --
#
#	Return the number of virtual desktops.

proc desktops {} {
    return
}

# swapspaces --
#
#	Do the actual swap.

proc swapspaces {ids dest} {
    foreach id $ids {
	exec wmctrl -ir $id -t $dest
    }
}

proc WindowList {} {
    set windowlist {}

    set oput [open "|wmctrl -lp"]
    while { ![eof $oput] } {
	gets $oput line
	if { $line eq "" } continue
	lappend windowlist [regsub -all " +" $line " "]
    }
    return $windowlist
}

proc UpdateWindowList {} {
    global windowlist
    set windowlist [WindowList]
}

proc WorkspaceWindowInfo {var workspacenum} {
    global windowlist
    set reslist {}

    set mypid [pid]

    foreach line $windowlist {
	set winfo [split $line]
	set id [lindex $winfo 0]
	set desktop [lindex $winfo 1]
	set pid [lindex $winfo 2]

	if { $pid == $mypid } {
	    continue
	}

	set comp [lindex $winfo 3]
	set name [lrange $winfo 4 end]
	# puts "$id $desktop -- $name"

	if { $desktop == $workspacenum } {
	    lappend reslist [set $var]
	}
    }
    return $reslist
}


# Stash --
#
#	Hide the windows away and save which ones were hidden where.

proc Stash {srcdeskselector dstdeskselector groupname} {
    set dst [$dstdeskselector get]
    set src [$srcdeskselector get]
    set groupname [$groupname get]

    puts "Moving $groupname from $src to $dst"

    # Has to have a name.
    if { $groupname eq "" } {
	# FIXME - error message.
	return
    }

    set ids [FetchIdsFromProjectList $groupname $src]
    UpdateProjectList $groupname $dst $ids
    SaveProjectList
    # Then, move them.

    swapspaces $ids $dst

    # Now update the widgets
    $dstdeskselector set $src
    $srcdeskselector set $dst
}

proc FetchIdsFromProjectList {groupname src} {
    global projectlist

    # If we already have a list of id's, use that.
    if { [dict exists $projectlist $groupname] } {
	return [lindex [dict get $projectlist $groupname] 1]
    } else {
	return [WorkspaceWindowInfo id $src]
    }
}

proc UpdateProjectList {groupname currentdesktop ids} {
    global projectlist

    dict set projectlist $groupname [list $currentdesktop $ids]
}

proc CurrentProjectDesktop {name} {
    if { $name eq "" } {
	return 0
    }

    global projectlist
    return [lindex [dict get $projectlist $name] 0]
}

proc SaveProjectList {} {
    global projectfile
    global projectlist
    set fl [open $projectfile w]
    puts $fl "set projectlist [list $projectlist]"
    close $fl
}

UpdateWindowList

set currentdesktop 0

proc GuiGroup {name i} {
    global desktops

    ttk::label .destl$i -text "Destination: " -font TkHeadingFont
    ttk::label .sourcel$i -text "Source: " -font TkHeadingFont
    ttk::label .windows$i -text "Windows: " -font TkHeadingFont

    # FIXME - names from ids
    ttk::combobox .windowlist$i -values [WorkspaceWindowInfo name 0]
    ttk::label .groupnamel$i -text "Group Name: " -font TkHeadingFont
    set groupname [ttk::entry .groupname$i]
    .groupname$i insert 0 $name


    set current [CurrentProjectDesktop $name]

    set srcselector [ttk::combobox .sourceselector$i -width 3 -values $desktops]
    $srcselector current $current

    set destselector [ttk::combobox .destselector$i -width 3 -values $desktops]
    # FIXME hardcoded 4
    $destselector current [expr {$current == 0 ? 4 : 0}]

    set button [ttk::button .swapbutton$i -text "Move" -command [list Stash $srcselector $destselector $groupname]]

    grid .groupnamel$i .groupname$i .windows$i .windowlist$i .sourcel$i .sourceselector$i .destl$i .destselector$i .swapbutton$i -sticky ew
}


GuiGroup "" 0
set i 1
foreach name [dict keys $projectlist] {
    GuiGroup $name $i
    incr i
}



#grid configure .deska -ipadx 15 -ipady 8

grid columnconfigure . 0 -weight 1
