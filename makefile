%.mkv: %.ogg
	ffmpeg -i $< -filter_complex "[0:a]showwaves=s=1280x720:mode=line:rate=25,format=yuv420p[v]" -map "[v]" -map 0:a $@

%.ogg: %.mid
	timidity $< -Ov -o $@

%.ogg: %.kar
	timidity $< -Ov -o $@

%.vtt: %.mid
	pike kar2vtt.pike -v -o-.25 $< >$@

%.vtt: %.kar
	pike kar2vtt.pike -v -o-.25 $< >$@

%.html: %.mkv %.vtt template.html
	sed <template.html 's/{{FN}}/'$(basename $(<F))'/' >$@

.PRECIOUS: %.mkv %.vtt
