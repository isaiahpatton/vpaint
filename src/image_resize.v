module main

import stbi
import gx
import os

fn (mut this Image) resize(w int, h int) {
	mut data := this.data

	this.zoom = 1

	tmp := os.temp_dir()
	path := os.join_path(tmp, 'vpaint-resized-temp.png')

	this.screenshot_png(path, w, h) or {}

	mut png_file := stbi.load(path) or { panic(err) }

	for x in 0 .. w {
		for y in 0 .. h {
			if x < this.w && y < this.h {
				a := get_pixel(x, y, data.file)
				set_pixel(png_file, x, y, a)
			} else {
				set_pixel(png_file, x, y, gx.white)
			}
		}
	}

	data.file = png_file
	this.data = data
	this.img = data.id
	this.w = png_file.width
	this.h = png_file.height
	this.width = data.file.width
	this.height = data.file.height
	this.loaded = false
}

fn (mut this Image) grayscale_filter() {
	this.note_multichange()
	for x in 0 .. this.w {
		for y in 0 .. this.h {
			rgb := this.get(x, y)
			gray := (rgb.r + rgb.g + rgb.b) / 3
			new_color := gx.rgb(gray, gray, gray)
			this.set2(x, y, new_color, true)
		}
	}
	this.refresh()
}

fn (mut this Image) invert_filter() {
	this.note_multichange()
	for x in 0 .. this.w {
		for y in 0 .. this.h {
			rgb := this.get(x, y)
			new_color := gx.rgb(255 - rgb.r, 255 - rgb.g, 255 - rgb.b)
			this.set(x, y, new_color)
			this.mark_batch_change()
		}
	}
	this.refresh()
}

[heap]
pub struct Screenshot {
	width  int
	height int
	size   int
mut:
	pixels &u8 = unsafe { nil }
}

[manualfree]
pub fn (mut this Image) screenshot_window(w int, h int) &Screenshot {
	img_size := w * h * 4
	img_pixels := unsafe { &u8(malloc(img_size)) }

	C.v_sapp_gl_read_rgba_pixels(0, 0, w, h, img_pixels)

	return &Screenshot{
		width: w
		height: h
		size: img_size
		pixels: img_pixels
	}
}

// free - free *only* the Screenshot pixels.
[unsafe]
pub fn (mut ss Screenshot) free() {
	unsafe {
		free(ss.pixels)
		ss.pixels = &u8(0)
	}
}

// destroy - free the Screenshot pixels,
// then free the screenshot data structure itself.
[unsafe]
pub fn (mut ss Screenshot) destroy() {
	unsafe { ss.free() }
	unsafe { free(ss) }
}

pub fn (mut this Image) screenshot_png(path string, w int, h int) ! {
	ss := this.screenshot_window(w, h)
	// stbi.set_flip_vertically_on_write(true)
	stbi.stbi_write_png(path, ss.width, ss.height, 4, ss.pixels, ss.width * 4)!
	unsafe { ss.destroy() }
}

fn (mut this Image) upscale() {
	mut data := this.data
	w := this.w * 2
	h := this.h * 2

	this.zoom = 1

	tmp := os.temp_dir()
	path := os.join_path(tmp, 'vpaint-resized-temp.png')

	this.screenshot_png(path, w, h) or {}

	mut png_file := stbi.load(path) or { panic(err) }

	for x in 0 .. w {
		for y in 0 .. h {
			set_pixel(png_file, x, y, gx.rgb(255, 0, 255))
		}
	}

	for x in 0 .. this.w {
		for y in 0 .. this.h {
			a := get_pixel(x, y, data.file)
			b := get_pixel(x + 1, y, data.file)

			n := mix_color(a, b)

			// Oringal
			set_pixel(png_file, x * 2, (y * 2), a)

			// Right
			set_pixel(png_file, (x * 2) + 1, (y * 2), n) // Right
		}
	}

	for x in 0 .. w {
		for y in 0 .. this.h {
			a := get_pixel(x, y * 2, png_file)
			b := get_pixel(x, (y * 2) + 2, png_file)

			n := mix_color(a, b)

			set_pixel(png_file, x, (y * 2) + 1, n) // Right
		}
	}

	unsafe {
		data.file.free()
	}
	data.file = png_file

	this.data = data
	this.img = data.id
	this.w = png_file.width
	this.h = png_file.height
	this.width = data.file.width
	this.height = data.file.height
	this.loaded = false
}
