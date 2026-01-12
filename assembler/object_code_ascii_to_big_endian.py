import argparse
from hashlib import file_digest

def main():
  parser = argparse.ArgumentParser()
  parser.add_argument(
      "input_file", type=str, help="Input file containing hack object code as ascii binary numbers, 16 bits per line"
  )
  parser.add_argument(
      "output_file", type=str, help="Output file containing hack object code as big endian bytes"
  )
  args = parser.parse_args()

  with open(args.input_file, "r") as input_file, open(args.output_file, "wb") as output_file:
    for n, line in enumerate(input_file):
      # if the line is not a number or is not 16 characters, errror
      line = line.strip()
      if line == "" or line.startswith("//"):
        continue
      if not line.isdigit() or len(line) != 16:
        print(f"Error: line {n} is not a 16-digit binary number")
        exit(1)
      # convert the line to a big-endian binary number
      line_bytes =int(line, 2).to_bytes(2, byteorder="big")
      output_file.write(line_bytes)

if __name__ == "__main__":
    main()