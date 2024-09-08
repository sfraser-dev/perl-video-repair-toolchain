- Tool chain fix video.
	- Perl file "getOriginalMediaData.pl" gets video parameters using MediaInfo.
	- Based on these parameters, "broken" videos are found.
	- These broken videos are then copied to a "fixMeVRT" folder. 
	- The user should then used the Grau Video Repair Tool (GUI, not command line) to fix the videos in the "fixMeVRT" folder.
	- The user should set the output folder of the Grau Video Repair Tool to "fixMeFFmpeg". 
	- Perl file "ffmpegSplitThenRecombineVRT.pl" should then be applied to the videos in the "fixMeFFmpeg" folder.
		- This makes sure the videos fixed by the Grau Video Repair Tool are the correct duration.

