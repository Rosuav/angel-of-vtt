%.mkv: %.wav
	ffmpeg -y -i $< -filter_complex "[0:a]showwaves=s=1280x720:mode=line:rate=25,format=yuv420p[v]" -map "[v]" -map 0:a $@

%.wav: %.kar
	timidity $< -Ow -o $@

%.vtt: %.kar
	pike kar2vtt.pike -v $< >$@

%.html: %.mkv %.vtt template.html
	sed <template.html 's/{{FN}}/'$(basename $(<F))'/' >$@

.PRECIOUS: %.mkv %.vtt
