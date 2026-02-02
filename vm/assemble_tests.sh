# loop over each argument
for file in $@; do
  echo "Assembling $file -> $file.hack"
  uv run python ../assembler/assembler.py $file > $file.hack  
done

wc -l *.hack
