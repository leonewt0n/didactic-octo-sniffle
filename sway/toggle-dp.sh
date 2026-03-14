# Name of your DP monitor output from your config
MONITOR="DP-2"

# Check if the monitor is currently enabled/active
# We use swaymsg to get output data and grep for the active status
IS_ACTIVE=$(swaymsg -t get_outputs | jq -r ".[] | select(.name==\"$MONITOR\") | .active")

if [ "$IS_ACTIVE" = "true" ]; then
    swaymsg output "$MONITOR" disable
else
    # Re-enable using your specific configuration:
    swaymsg output "$MONITOR"  pos 3840 0 enable
fi
