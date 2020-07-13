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
	//Currently renders only one track of lyrics. If it becomes an issue,
	//add an optional step here to flatten to SMF0.
	sscanf(chunks[0][1],"%2c%*2c%2c",int type,int timediv); //timediv == ticks per quarter note
	//if (time_division&0x8000) //it's SMPTE timing?
	int tempo=500000,bpm=120;
	float time_division=tempo*.000001/timediv;

	write("WEBVTT\n\n");
	foreach (chunks; int i; [string id, array chunk]) if (id == "MTrk")
	{
		int pos = 0, linestart = 0, lastlyric = 0;
		array lines = ({ });
		string line = "";
		foreach (chunk; int ev; array data)
		{
			pos += data[0];
			//data == ({delay, command[, args...]})
			if (data[1] == 255 && data[2] == 5) //NOTE: Not currently supporting the use of text (data[2]==1) for lyrics.
			{
				string words = data[3];
				//write("%5d %s\n", pos, replace(words, (["\r": "\\r", "\n": "\\n"])));
				int new_para = has_value(words, '\r') || has_value(words, '\n');
				words = words - "\r" - "\n";
				if (line == "") linestart = pos;
				if (words != "") line += sprintf("<%s><c>%s</c>", hms(pos * time_division), words);
				if (new_para && line != "")
				{
					lines += ({({line, linestart, pos})});
					line = "";
				}
				lastlyric = pos;
			}
		}
		if (line != "") lines += ({({line, linestart, lastlyric})});
		if (!sizeof(lines)) continue;
		//Combine lines into pairs. TODO: Don't combine across a large gap.
		array pairs = ({ });
		foreach (lines / 2, [array line1, array line2])
			pairs += ({({line1[0] + "\n" + line2[0], line1[1], line2[2]})});
		lines = pairs + lines % 2;
		int prevend = 0, prevprevend = 0;
		//TODO: Figure out what's wrong with the playback rate
		//For some reason, the lyrics are being played too fast - sometimes a LOT too fast.
		//They also seem to start at the wrong time but I'm not sure why.
		foreach (lines; int i; [string line, int start, int end])
		{
			int nextnextstart = i < sizeof(lines) - 2 ? lines[i + 2][1] : pos;
			int gapbefore = start - prevprevend;
			int gapafter = nextnextstart - end;
			float preempt = min(gapbefore / 2 * time_division - 0.0625, 2.5);
			float linger = min(gapafter / 2 * time_division - 0.0625, 5.0);
			write("%s --> %s\n%s\n\n",
				hms(start * time_division - preempt), //Start a bit before the first lyric syllable
				hms(end * time_division + linger), //Linger a bit after the last lyric syllable
				line,
			);
			while (sscanf(line, "%s<%*s>%s", string q, string w) && w) line = q + w;
			if (verbose) werror("%1.3f %5d %5d %1.3f %s\n", preempt, start, end, linger, line);
			prevprevend = prevend; prevend = end;
		}
	}
}

int main(int argc, array(string) argv)
{
	foreach (argv[1..], string arg) build_vtt(arg);
}
