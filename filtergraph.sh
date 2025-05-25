#!/bin/sh
#
# log_bargraph.sh - Visualizes pfSense parsed filter logs as ASCII bar graphs.
#
# Usage:
#   ./log_bargraph.sh field [max_bar_length] [inputfile]
#
#   field:          hour | srcip | dstip | iface | srcport | dstport
#   max_bar_length: (optional) max width of bar (default: 50)
#   inputfile:      (optional) input file, defaults to stdin
#
# Examples:
#   zgrep "block" /var/log/filter.log* | filterparser.php | ./log_bargraph.sh hour
#   ./log_bargraph.sh srcip 60 parsed_filter.log
#   ./log_bargraph.sh dstport 40 parsed_filter.log

FIELD="$1"
MAX_BAR="${2:-50}"
INPUT="${3:-/dev/stdin}"

if [ -z "$FIELD" ]; then
    echo "Usage: $0 field [max_bar_length] [inputfile]"
    echo "Fields: hour | srcip | dstip | iface | srcport | dstport"
    exit 1
fi

TMPDATA="/tmp/bargraph_data.$$"
TMPMAX="/tmp/bargraph_max.$$"

# Extract desired field and set headers
case "$FIELD" in
    hour)
        awk '/block/ { split($3, t, ":"); print t[1] }' "$INPUT" | sort | uniq -c > "$TMPDATA"
        LABEL="Hour"
        HEADER="Hour | Blocks"
        ;;
    srcip)
        awk '/block/ { split($7, a, ":"); print a[1] }' "$INPUT" | sort | uniq -c | sort -nr | head -n 50 > "$TMPDATA"
        LABEL="Source IP (top 50)"
        HEADER="Source IP           | Blocks"
        ;;
    dstip)
        awk '/block/ { split($8, a, ":"); print a[1] }' "$INPUT" | sort | uniq -c | sort -nr | head -n 50 > "$TMPDATA"
        LABEL="Destination IP (top 50)"
        HEADER="Destination IP      | Blocks"
        ;;
    iface)
        awk '/block/ { print $5 }' "$INPUT" | sort | uniq -c > "$TMPDATA"
        LABEL="Interface"
        HEADER="Interface   | Blocks"
        ;;
    srcport)
        awk '/block/ { split($7, a, ":"); print a[2] }' "$INPUT" | sort | uniq -c | sort -nr | head -n 50 > "$TMPDATA"
        LABEL="Source Port (top 50)"
        HEADER="Source Port         | Blocks"
        ;;
    dstport)
        awk '/block/ { split($8, a, ":"); print a[2] }' "$INPUT" | sort | uniq -c | sort -nr | head -n 50 > "$TMPDATA"
        LABEL="Destination Port (top 50)"
        HEADER="Destination Port    | Blocks"
        ;;
    *)
        echo "Unknown field: $FIELD"
        rm -f "$TMPDATA" "$TMPMAX"
        exit 1
        ;;
esac

# Find the maximum value for scaling
awk '{if($1>max) max=$1} END{print max}' "$TMPDATA" > "$TMPMAX"
MAXVAL=$(cat "$TMPMAX")

# Print header
echo
echo "$LABEL bar chart (bars scaled to max $MAX_BAR chars)"
echo "$HEADER"
echo "-----------------------------------------------"

# Print ASCII bar graph
awk -v maxbar="$MAX_BAR" -v maxval="$MAXVAL" -v field="$FIELD" '
{
    if (field == "hour")         { labelfmt = "%-4s | "; label = $2 }
    else if (field == "iface")   { labelfmt = "%-10s | "; label = $2 }
    else                         { labelfmt = "%-18s | "; label = $2 }

    len = (maxval>0) ? int(($1/maxval)*maxbar) : 0;
    if(len<1 && $1>0) len=1;
    printf labelfmt, label;
    for(i=0;i<len;i++) printf "#";
    printf(" (%d)\n", $1);
}' "$TMPDATA"

rm -f "$TMPDATA" "$TMPMAX"
