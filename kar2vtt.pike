//Read a MIDI Karaoke file and create a VTT for its words

object midilib = (object)"../shed/patchpatch.pike";
int verbose = 0;
float offset = 0.0;

string hms(float tm)
{
	tm += offset;
	int sec = (int)tm, ms = (int)(tm * 1000);
	int min = sec / 60, hr = sec / 3600;
	return sprintf("%02d:%02d:%02d.%03d", hr, min % 60, sec % 60, ms % 1000);
}

void build_vtt(string fn)
{
	if (fn == "--verbose" || fn == "-v") {verbose = 1; return;}
	if (sscanf(fn, "-o%f", float ofs)) {offset = ofs; return;} //Use "-o-.25" to pull the lyrics a quarter second earlier
	array(array(string|array(array(int|string)))) chunks;
	if (catch {chunks = midilib->parsesmf(Stdio.read_file(fn));}) return;
	sscanf(chunks[0][1],"%2c%*2c%2c",int type,int timediv); //timediv == ticks per quarter note
	//if (time_division&0x8000) //it's SMPTE timing?
	int tempo=500000,bpm=120;
	float time_division=tempo*.000001/timediv;

	write("WEBVTT\n\n");
	//Flatten the MTrk chunks into a single stream of MIDI events
	int active = 0;
	foreach (chunks; int i; [string id, array chunk])
		if (id == "MTrk") {chunks[i] = ({chunk, 0}); ++active;} else chunks[i] = ({0, -1});
	array(array(int|string)) events = ({ });
	while (active)
	{
		//Pick the earliest event from the currently active chunks
		int advance = 1<<60; //pretend that that's infinity plsthx
		int sc = 0;
		foreach (chunks; int i; [array chunk, int pos]) if (chunk)
		{
			int delay = chunk[pos][0];
			if (delay > advance) continue;
			advance = delay; sc = i;
			if (!delay) break; //There's an immediate event. Don't bother looking elsewhere.
		}
		[array chunk, int pos] = chunks[sc];
		//Consume this event and put it onto the single stream
		events += ({chunk[pos]});
		if (pos + 1 >= sizeof(chunk)) {chunks[sc][0] = 0; --active;} //Past the end? No longer active.
		else chunks[sc][1] = pos + 1;
		//Shorten each other event's delay by the delay on this one
		if (!advance) continue; //Fast path for immediate events
		foreach (chunks; int i; [array chunk, int pos]) if (chunk && i != sc)
		{
			//assert chunk[pos][0] >= advance
			chunk[pos][0] -= advance;
		}
	}
	float pos = 0, linestart = 0, lastlyric = 0;
	array lines = ({ });
	string line = "";
	int no_lyrics = 1;
	foreach (events; int ev; array data)
	{
		pos += data[0] * time_division;
		//data == ({delay, command[, args...]})
		if (data[1] != 255) continue; //Actual notes and stuff don't matter :)
		//Type 1 (Text) can only be lyrics if not at the start of the track.
		if (data[2] == 5) no_lyrics = 0; //And only if we've never had any type 5 lyrics.
		if (data[2] == 5 || (data[2] == 1 && pos > 0.0 && no_lyrics))
		{
			string words = data[3];
			//write("%.3f %s\n", pos, replace(words, (["\r": "\\r", "\n": "\\n"])));
			int new_para = has_value(words, '\r') || has_value(words, '\n');
			words = words - "\r" - "\n";
			if (line == "") linestart = pos;
			if (words != "") line += sprintf("<%s><c>%s</c>", hms(pos), words);
			if (new_para && line != "")
			{
				lines += ({({line, linestart, pos})});
				line = "";
			}
			lastlyric = pos;
		}
		if (data[2] == 0x51) //Set Tempo
		{
			sscanf(data[3], "%3c", tempo);
			if (verbose) werror("[%.3f] Set Tempo: %d\n", pos, tempo);
			time_division = tempo * .000001 / timediv;
		}
	}
	if (line != "") lines += ({({line, linestart, lastlyric})});
	if (verbose) werror("End pos: %s\n", hms(pos));
	//Combine lines into pairs. TODO: Don't combine across a large gap.
	array pairs = ({ });
	foreach (lines / 2, [array line1, array line2])
		pairs += ({({line1[0] + "\n" + line2[0], line1[1], line2[2]})});
	lines = pairs + lines % 2;
	float prevend = 0, prevprevend = 0;
	//TODO: Figure out what's wrong with the playback rate
	//For some reason, the lyrics are being played too fast - sometimes a LOT too fast.
	//They also seem to start at the wrong time but I'm not sure why.
	foreach (lines; int i; [string line, float start, float end])
	{
		float nextnextstart = i < sizeof(lines) - 2 ? lines[i + 2][1] : pos;
		float gapbefore = start - prevprevend;
		float gapafter = nextnextstart - end;
		float preempt = min(gapbefore / 2, 2.0);
		float linger = min(gapafter / 2, 2.5);
		write("%s --> %s\n%s\n\n",
			hms(start - preempt), //Start a bit before the first lyric syllable
			hms(end + linger), //Linger a bit after the last lyric syllable
			line,
		);
		while (sscanf(line, "%s<%*s>%s", string q, string w) && w) line = q + w;
		if (verbose) werror("%1.3f %.3f %.3f %1.3f %s\n", preempt, start, end, linger, replace(line, "\n", " "));
		prevprevend = prevend; prevend = end;
	}
}

int main(int argc, array(string) argv)
{
	foreach (argv[1..], string arg) build_vtt(arg);
}
