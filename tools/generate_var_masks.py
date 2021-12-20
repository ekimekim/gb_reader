"""
Converts the given image containing a var-width font into an asm file.
Expects the image to be black and white and consist of one char per 8 pixels vertically,
with chars up to 8 pixels wide. Ignores anything past 8th column.
Char width is defined as 1 pixel more than the right-most on pixel in the char.

The output format is a char size table + a list of char tables corresponding to each char in the file.
The char size table is a list of 1 byte per char indicating how many pixels wide it is.
It is followed by padding such that the char table list is 256-byte aligned.
Each char table is 128 bytes and contains 8 char renditions, one for each possible
"start bit" from 0 to 7. Each rendition is split into an 8-byte first tile and an 8-byte
second tile, with each byte of a tile being a row of 1-bit pixels.

For example, consider the following image of a "4" character:
	#
	#
	# #
	####
	  #
	  #
	  #
It would be encoded like this in rendition 0
(where the second column comes completely after the first):
	10000000 00000000
	10000000 00000000
	10100000 00000000
	11110000 00000000
	00100000 00000000
	00100000 00000000
	00100000 00000000
	00000000 00000000
however, in later renditions it is shifted right, eg. rendition 6:
	00000010 00000000
	00000010 00000000
	00000010 10000000
	00000011 11000000
	00000000 10000000
	00000000 10000000
	00000000 10000000
	00000000 00000000
"""

from PIL import Image


def main(filepath):
	image = Image.open(filepath)

	image = image.convert('1')

	chars = image_to_chars(image) # returns [(size, [8x8 tile as list of ints])]
	sizes = []
	tables = []
	for size, pixels in chars:
		sizes.append(size)
		for rendition in range(8):
			tables += render_rendition(pixels, rendition) # returns 16-byte rendition as list of ints

	data = sizes + [0] * (256 - len(sizes)) + tables
	for byte in data:
		assert 0 <= byte < 256
		print "db {}".format(byte)


def image_to_chars(image):
	width, height = image.size
	if width < 8:
		raise ValueError("Image must be at least 8px wide")

	for y in range(0, height, 8):
		yield extract_char(image, y)


def extract_char(image, base_y):
	tile = []
	max_x = 0
	for y in range(base_y, base_y + 8):
		row = 0
		for x in range(8):
			pixel = image.getpixel((x, y))
			value = 0 if pixel == 255 else 1
			if value:
				max_x = x
			row = (row << 1) + value
		tile.append(row)
	# add 1 to max_x as we're going from 0-based coord to width, but also add 1 for char padding
	return max_x + 2, tile


def render_rendition(pixels, rendition):
	first = []
	second = []
	for row in pixels:
		shifted = row << (8 - rendition)
		first.append(shifted // 256)
		second.append(shifted % 256)
	return first + second


if __name__ == '__main__':
	import argh
	argh.dispatch_command(main)
