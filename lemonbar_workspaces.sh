#!/bin/sh
# Tam's lemonbar workspaces (depends on xprop)
# Supports active, inactive and busy formatting
# Supports switching by clicking and scrolling (depends on xdotool)

# SETTINGS

separator=" "

# Formatting help: https://github.com/LemonBoy/bar
# Formatting for active workspace
active_left="%{B#D12525}"
active_right="%{B}"
# Formatting for inactive workspaces
inactive_left=
inactive_right=
# Formatting for inactive workspaces with at least one window in them
# If you leave these variables empty all non-active workspaces
# will be considered inactive and performance will increase slightly
busy_left="%{B#13FF00}"
busy_right="%{B}"


##############################################################################


main() {
	# Get initial workspace list and active workspace and
	# subscribe to changes in those atoms.
	# We subscribe to _NET_CLIENT_LIST_STACKING instead of
	# just _NET_CLIENT_LIST because the latter is not
	# triggered when windows are sent to another workspace.
	xprop -root -spy _NET_CURRENT_DESKTOP \
	                 _NET_DESKTOP_NAMES \
                         _NET_CLIENT_LIST_STACKING |
		while IFS="[ =]" read -r atom value; do
			# Every time one of these atoms
			# changes, print a new workspace list.
			case "$atom" in
				*CLIENT*)
					# Only update the workspace list
					# if busy formatting has been set.
					if [ -n "$busy_left" ] ||
					   [ -n "$busy_right" ]; then
						make_ws_list windows_changed
					fi
					;;

				*CURRENT*)
					active_ws="$value"
					make_ws_list
					;;

				*NAMES*)
					ws_names="$value"
					make_ws_list ;;
			esac
		done
}


make_ws_list() {
	# Update list of busy workspaces if windows have changed.
	if [ "$1" = "windows_changed" ]; then
		old_busy_wspaces="$busy_wspaces"
		busy_wspaces=$(get_busy_wspaces)

		# If the list of busy workspaces hasn't changed,
		# abort. No need to re-generate the same list.
		if [ "$old_busy_wspaces" = "$busy_wspaces" ]; then
			return
		fi
	fi

	# Set workspace names as positional args
	# so that we can loop through them.
	set -f
	set -- $ws_names

	# Loop through the workspace names.
	i=0; for ws; do
		# Trim leftover quotes and commas.
		formatted_ws_name=${ws%,}
		formatted_ws_name=${formatted_ws_name%\"}
		formatted_ws_name=${formatted_ws_name#\"}

		# Print separator before all workspaces
		# except the first.
		test "$i" != 0 && printf "%s" "$separator"

		# Print on-click lemonbar formatting.
		printf "%s" "%{A1:xdotool set_desktop $i:}"
		printf "%s" "%{A4:xdotool set_desktop --relative 1:}"
		printf "%s" "%{A5:xdotool set_desktop --relative -- -1:}"

		# If workspace is the active one,
		# print workspace name with active formatting
		if [ "$i" = "$active_ws" ]; then
			printf "%s" "$active_left$formatted_ws_name$active_right"

		# If the workspace is not active...
		else
			# ... and formatting for busy workspaces was set...
			if [ -n "$busy_left" ] || [ -n "$busy_right" ]; then

				# ...check if the workspace is busy.

				# Reset positional arguments to busy workspaces
				# so that we can loop through them.
				set -- $busy_wspaces

				# Loop through the list of busy workspaces.
				for busy_ws; do
					# If workspace is found among the list of
					# busy workspaces, then print it with
					# busy formatting
					if [ "$i" = "$busy_ws" ]; then
						printf "%s" "$busy_left$formatted_ws_name$busy_right"
						break
					fi
				done
			fi

			# If the workspace was not found to be busy,
			# just print inactive formatting
			# If formatting for busy workspaces is unset
			# then this will always print inactive formatting.
			if [ "$i" != "$busy_ws" ]; then
				printf "%s" "$inactive_left$formatted_ws_name$inactive_right"
			fi

			# Reset positional parameters to workspace names
			# so that the next iteration of `for ws` works
			# correctly.
			set -- $ws_names
		fi

		# Close on-click lemonbar formatting.
		printf "%s" "%{A}%{A}%{A}"

		# Set id of next iterated workspace.
		i=$(( i + 1 ))
	done

	echo ""
	set +f
}


get_busy_wspaces() {
	unset busy_wspaces

	# Store list of window IDs in a string.
	window_list=$(xprop -root _NET_CLIENT_LIST)
	window_list=${window_list#*\# }

	# Set the window list as positional
	# arguments as a ghetto POSIX array
	# so we can loop through them.
	set -f
	set -- $window_list

	# Iterate through each window ID.
	for wid; do
		# Get the workspace that this window is in.
		wid_ws=$(xprop -id "$wid" _NET_WM_DESKTOP)
		wid_ws=${wid_ws#*= }

		# Reset positional arguments to busy workspaces
		# so that we can loop through them.
		set -- $busy_wspaces

		# If we already know this window's workspace
		# is busy then move on to the next WID.
		for busy_ws; do
			if [ "$wid_ws" = "$busy_ws" ]; then
				# Restore window list as positionals so
				# the next iteration of `for wid`
				# doesn't find a workspace id.
				set -- $window_list
				# Break out of this loop and skip
				# the rest of the parent loop's current
				# iteration.
				continue 2
			fi
		done
		# If we didn't already know then
		# add that workspace to the list.
		busy_wspaces="$busy_wspaces $wid_ws"

		# Restore window list as positionals so
		# the next iteration of `for wid`
		# doesn't find a workspace id.
		set -- $window_list
	done
	
	echo "$busy_wspaces"
	set +f
}


main
