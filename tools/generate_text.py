
"""
Takes text on stdin and formats and encodes it into an asm file on stdout.
This asm file can be imported directly and defines its own SECTIONs.
Requires a json list of character lengths, where the first entry is space.

If --plaintext is given, instead of printing asm, it prints the data as ascii text
with newlines in place of NUL. This is useful for checking how lines will be wrapped.
"""

import json
import re
import sys


def main(widths_file, start_bank=2, plaintext=False):
	with open(widths_file) as f:
		widths = json.load(f)

	for bank, data in process_text(widths, sys.stdin, start_bank):
		print 'SECTION "Text Data Bank {bank}", ROMX[$4000], BANK[{bank}]'.format(bank=bank)
		if plaintext:
			print data.replace("\0", "\n")
		else:
			for char in data:
				print "db {}".format(ord(char))


def process_text(widths, input, bank):
	BANK_MAX = 0x4000 - 1
	buf = ""
	bank_data = ""
	for chunk in process_lines(widths, input):
		buf += chunk
		while "\0" in buf:
			line, buf = buf.split("\0", 1)
			line += "\0"
			if len(bank_data) + len(line) > BANK_MAX:
				yield bank, bank_data + "\xff"
				bank += 1
				bank_data = ""
			bank_data += line
	assert buf == "", "no trailing newline"
	yield bank, bank_data


def process_lines(widths, input):
	LINE_MAX = 20 * 8
	SPACE_LEN = widths[0]
	for line in input:
		line = line.strip('\n')
		# Some common replacements for non-printing or non-ascii chars to an ascii equivalent
		line = line.replace("\t", "    ")
		line = line.replace("\xe2\x80\x93", "-") # en dash
		line = line.replace("\xe2\x80\x94", "-") # em dash
		line = line.replace("\xe2\x80\x98", "'") # smart quote
		line = line.replace("\xe2\x80\x99", "'") # smart quote
		line = line.replace("\xe2\x80\x9c", '"') # smart quote
		line = line.replace("\xe2\x80\x9d", '"') # smart quote
		# Replace any other non-ascii characters with 7f, which we use as "invalid char"
		line = re.sub("[^ -~]", "\x7f", line)
		words = line.split(" ")
		line_pos = 0
		while words:
			word = words.pop(0)
			length = sum(widths[ord(c) - 32] for c in word)
			# Handle reaching end of line. Remember to include the space we're going to insert
			# if this isn't the start of a line.
			word_pos = line_pos + SPACE_LEN if line_pos != 0 else 0
			if word_pos + length > LINE_MAX:
				if line_pos != 0:
					yield '\0'
					line_pos = 0
				# If we're at the start of the line and a word still doesn't fit,
				# handle it by splitting the word. We insert the partial word back,
				# so if its still too long this block will be hit multiple times.
				if length > LINE_MAX:
					word, remainder = split_word(widths, word, LINE_MAX)
					words.insert(0, remainder)
			elif line_pos != 0:
				# if no newline and not at the start of line, add a space from previous word
				yield " "
				line_pos += SPACE_LEN
			yield word
			line_pos += length
		yield '\0'
	# Book ends with 20 blank lines as padding.
	yield '\0' * 20


def split_word(widths, word, LINE_MAX):
	DASH_LEN = widths[ord("-") - 32]
	length = 0
	for i, char in enumerate(word):
		char_length = widths[ord(char) - 32]
		# Break if after this char, we wouldn't have enough to add a dash.
		# This also handles the case where it would put us over directly.
		if length + char_length + DASH_LEN > LINE_MAX:
			split_at = i
			break
	else:
		assert False, "word was too long but counting characters wasn't"
	assert 0 < split_at < len(word)
	return word[:split_at] + "-", word[split_at:]


if __name__ == '__main__':
	import argh
	argh.dispatch_command(main)
