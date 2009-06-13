#!/usr/bin/tclsh8.5

package require Tk

# desktops --
#
#	Return the number of virtual desktops.

proc desktops {} {
    return [llength [split [exec wmctrl -d] "\n"]]
}

# swapspaces --
#
#	Do the actual swap.

proc swapspaces {source dest} {
    set sourcelist {}
    set destlist {}

    set oput [open "|wmctrl -l"]
    while { ![eof $oput] } {
	gets $oput line
	set winfo [split $line]
	set id [lindex $winfo 0]
	set desktop [lindex $winfo 2]

	if { $desktop == $source } {
	    lappend sourcelist $id
	} elseif { $desktop == $dest } {
	    lappend destlist $id
	}
    }

    foreach id $destlist {
	exec wmctrl -ir $id -t $source
    }

    foreach id $sourcelist {
	exec wmctrl -ir $id -t $dest
    }
    close $oput
}

# Swap --
#
#	Respond to the swap button.

proc Swap {a b} {
    set ai [$a get]
    set bi [$b get]
    if { [catch {
	incr ai -1
	incr bi -1
    } err] } {
	$a set 1
	$b set 1
    }
    swapspaces $ai $bi
}

ttk::label .swap -text "Swap Desktops" -font TkHeadingFont
ttk::label .deska -text "Desktop A:"
ttk::label .deskb -text "Desktop B:"

set desktops [desktops]
for {set i 1} {$i < $desktops + 1} {incr i} {
    lappend dtlist $i
}

set a [ttk::combobox .a -width 3 -values $dtlist]
set b [ttk::combobox .b -width 3 -values $dtlist]
$a current 0
$b current [expr {$desktops / 2 - 1}]
set button [ttk::button .swapbutton -text "Swap" -command [list Swap $a $b]]

grid .swap -
grid .deska .a -sticky ew
grid .deskb .b -sticky ew

grid configure .deska -ipadx 15 -ipady 8
grid configure .deskb -ipadx 15 -ipady 8

grid $button - -sticky ew -ipady 8
grid columnconfigure . 0 -weight 1
