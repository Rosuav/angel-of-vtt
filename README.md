Tinkering and toying with the VTT format
========================================

(yeah, that's not a very coherent project goal, but the pieces are kinda
disparate at the moment)

* Create a VTT file from a MIDI karaoke file
* TODO: Play multiple consecutive files in HTML5. Is there a gap?
* If not, consider an amalgamated file. Generate a title card for each input
  file, "title-001.png" etc. Then build the images into a movie thus:
  - ffmpeg -i title-%3d.png -vf "zoompan=d=123*eq(in,0)+234*eq(in,1)" output.mkv
  - TODO: Figure out how best to combine this with the audio in one step.
  - The zoompan=d= expression consists of "+".join("%d*eq(in,%d)" % (dur, idx))
    for every duration (in frames) that we want to use. This isn't exactly the
    tidiest way to do an array lookup, but I don't think FFMPEG has any better.
  - The default is 25fps. May need to change that.
* It's not possible to play audio with subtitles (even in a <video> tag), so
  we generate a visualization using ffmpeg.


The MIT License (MIT)

Copyright (c) 2020 Chris Angelico

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
