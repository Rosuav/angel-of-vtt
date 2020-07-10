//Read a MIDI Karaoke file and create a VTT for its words

object midilib = (object)"../shed/patchpatch.pike";
int verbose = 0;

string hms(float tm)
{
	int sec = (int)tm, ms = (int)(tm * 1000);
	int min = sec / 60, hr = sec / 3600;
	return sprintf("%02d:%02d:%02d.%03d", hr, min % 60, sec % 60, ms % 1000);
}

void audit(string fn)
{
	if (fn == "--verbose" || fn == "-v") {verbose = 1; return;}
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
		int pos = 0, new_para;
		string cue = 0;
		foreach (chunk; int ev; array data)
		{
			pos += data[0];
			//data == ({delay, command[, args...]})
			if (data[1] == 255 && data[2] == 5) //NOTE: Not currently supporting the use of text (data[2]==1) for lyrics.
			{
				if (new_para && cue)
				{
					write("%s\n\n", replace(cue, "\xFFFD", hms(pos * time_division)));
					cue = 0;
				}
				//TBJ 00:00:24ish "Hark" == 9216
				string words = data[3];
				new_para = has_value(words, '\r') || has_value(words, '\n');
				words = words - "\r" - "\n";
				if (words != "")
				{
					if (!cue)
						cue = hms(pos * time_division) + " --> \xFFFD\n" + words;
					else
						cue += sprintf("<%s><c>%s</c>", hms(pos * time_division), words);
				}
			}
		}
		if (cue) write("%s\n\n", replace(cue, "\xFFFD", hms(pos * time_division)));
	}
}

int main(int argc, array(string) argv)
{
	foreach (argv[1..], string arg) audit(arg);
}
