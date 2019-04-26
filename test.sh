#!
find ./jobs -type f | sort | while read fn; do
  x=`./joblex < $fn`
  printf "%-36s %s\n" "$x" "$fn"
done
