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

set projectfile "~/.swapspacesprojects.tcl"

# Current list of projects
set projectlist [dict create]

# Try loading projectlist from here:
catch {
    source $projectfile
}

# Desktop list
set desktops []
foreach d [split [exec wmctrl -d] "\n"] {
    lappend desktops [lindex $d 0]
}


# swapspaces --
#
#	Do the actual swap.

proc swapspaces {ids dest} {
    foreach id $ids {
	puts "wmctrl -ir $id -t $dest"
	exec wmctrl -ir $id -t $dest
    }
}

# CurrentDesktop --
#
#	Returns the number of the current desktop

proc CurrentDesktop {} {
    set oput [open "|wmctrl -d"]
    while { ![eof $oput] } {
	gets $oput line
	# Find the line with the asterisk.
	if { [regexp {^(\d*) +\*} $line match desktop] } {
	    close $oput
	    return $desktop
	}
    }
    close $oput
    return 0
}

# Fetch list of windows

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

# Update the system's information.

proc UpdateWindowList {} {
    global windowlist
    set windowlist [WindowList]
}

# WorkspaceWindowInfo --
#
#	Takes a variable name $var and a workspacenum and returns
#	information about the windows there - you can get names, ids
#	pids or whatever.

proc WorkspaceWindowInfo {var workspacenum} {
    global windowlist
    set reslist {}

    set myid [wm frame .]

    foreach line $windowlist {
	set winfo [split $line]
	set id [lindex $winfo 0]
	set desktop [lindex $winfo 1]
	set pid [lindex $winfo 2]

	# puts "$id $myid [winfo id .]"

	# if { $id == $myid } {
	#     puts "match!"
	#     continue
	# }

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
#	This is where most of the actual work is.

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

    set ids [FetchIdsFromProjectList $groupname]

    swapspaces $ids $dst

    # Now update the widgets
    $dstdeskselector set $src
    $srcdeskselector set $dst
}

# FetchIdsFromProjectList --
#
#	Given a src workspace and a group name, use the stored dict
#	information if it's present, otherwise fetch window
#	information.

proc FetchIdsFromProjectList {groupname} {
    return [lindex [dict get $::projectlist $groupname] 1]
}

# UpdateProjectList --
#
#	Store information about project $groupname.

proc UpdateProjectList {groupname currentdesktop ids} {
    puts "Adding $ids to $groupname"
    dict set ::projectlist $groupname [list $currentdesktop $ids]
    puts $::projectlist
}

# CurrentProjectDesktop --
#
#	Get the stored desktop for the current project.

proc CurrentProjectDesktop {name} {
    if { $name eq "" } {
	return 0
    }

    return [lindex [dict get $::projectlist $name] 0]
}

# SaveProjectList --
#
#	Save the projectlist to a file.

proc SaveProjectList {} {
    global projectfile
    global projectlist
    set fl [open $projectfile w]
    puts $fl "set projectlist [list $projectlist]"
    close $fl
}

# RefreshWindowList --
#
#	Adds all windows on the current desktop to the list

proc RefreshWindowList {srcdeskselector groupname} {
    set name [$groupname get]
    set src [$srcdeskselector get]

    if { $src == [CurrentDesktop] } {
	UpdateWindowList
	set currentlist [WorkspaceWindowInfo id $src]

	puts "currentlist is $currentlist"

	UpdateProjectList $name $src $currentlist
	SaveProjectList
    }
}

# GuiGroup --
#
#	Create a group of gui controls for a specific

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
    set refresh [ttk::button .refreshb$i -text "Refresh Window List" -command [list RefreshWindowList $srcselector $groupname]]

    grid .groupnamel$i .groupname$i .windows$i .windowlist$i .sourcel$i .sourceselector$i .destl$i .destselector$i $button $refresh -sticky ew
}

UpdateWindowList

set i 0

# Create a default group if there are none.
if { [dict size $projectlist] == 0 } {
    GuiGroup "" $i
    incr i
}

foreach name [dict keys $projectlist] {
    GuiGroup $name $i
    incr i
}

#grid configure .deska -ipadx 15 -ipady 8

grid columnconfigure . 0 -weight 1
