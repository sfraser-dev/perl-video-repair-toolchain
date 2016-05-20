#!/usr/bin/perl -w

# Need Perl installed on your system / directory.
# Strawberry Perl can be downloaded from:
# http://strawberryperl.com/

# Need to install the CLI version of MediaInfo in your system / directory:
# https://mediaarea.net/en/MediaInfo/Download/Windows

# Need to install FFmpeg in your system / directory.
# A static FFmpeg build can be obtained from:
# https://ffmpeg.zeranoe.com/builds/

use strict;
use warnings;
use feature qw(say);
use File::Find; 
use File::Basename;
use Cwd;
use POSIX qw(floor);

my $name;
my $fileDir;
my $ext;
my $cwdPath;
my @content;
my $originalFileNameFullPath;
my $numAudStrms;
my $numVidStrms;
my $audDurMilliSecs;
my $vidDurMilliSecs;
my $framesPerSec;
my $audDurSecs;
my $vidDurSecs;
my $command;
my @commandOutput;
my $imgDir;
my $logFile;
my $fh;
my $expectedNumFrames;
my $vidBitRateBps;
my $frameCount;
my @dirFileCountFFmpegArr;
my $dirFileCountFFmpeg;
my $newTargetFramerate;
my $mediaLog;
my $fh_log;
my @mediaLine;
my $mediaLine;
my @audioSplit;
my $originalAudioDur;
my $originalVideoDur;
my $originalFPS;
my $originalBitrate;
my $reconVideoName;
my $fixOrKeepVideo;
my $iSurveyPerlFixFolder;
my $mediaDataLog;
my $perlFilenameBase;
my $vidFixedByVRTFolder;
my $datFile;
my $fh_dat;
my $reconAudioName;
my $originalVidName;
my $originalVidFolder;
my $originalVidBaseName;
my $brokenVideoName;
my $currentVRTVidName;
my $newVRTVidName;
my $muxedVidName;

# Do not change this folder or log name
$iSurveyPerlFixFolder = "C:\\iSurveyMediaFix";
$mediaDataLog = $iSurveyPerlFixFolder."\\getOriginalMediaData.log";

# checking the iSurvey folder exists
if (-d $iSurveyPerlFixFolder){
    say "using folder '$iSurveyPerlFixFolder'";
}
else {
    say "Error: folder '$iSurveyPerlFixFolder' doesn't exist";
    exit;
}

# checking the log data exists
if (-e $mediaDataLog){
    say "using file '$mediaDataLog'";
}
else {
    say "Error: file '$mediaDataLog' doesn't exist";
    exit;
}

# create a file for logging
$perlFilenameBase=basename($0);
$perlFilenameBase=~s/\.pl//;
$logFile = $iSurveyPerlFixFolder."\\$perlFilenameBase\.log";
open ($fh, '>', $logFile) or die ("Could not open file '$logFile' $!");

# reading the folder with the VRT repaired videos from the .dat file
$datFile=$iSurveyPerlFixFolder."\\vrtFixedVideoFolder\.dat";
open ($fh_dat, '<', $datFile) or die("Could not open file '$datFile'.");
while(my $line = <$fh_dat>){
    $vidFixedByVRTFolder = $line;
}
chomp $vidFixedByVRTFolder;

# read the media info log (from the original video) that was written to file into an array
$mediaLog = $mediaDataLog;
open ($fh_log, '<', $mediaLog) or die ("Could not open file '$mediaLog' $!");
@mediaLine = <$fh_log>;
close $fh_log;

# find all MP4 files from current and sub directories
find( \&fileWanted, $vidFixedByVRTFolder); 

foreach my $vidName (@content) {
    # get filename, directory and extension of the found video
    ($name,$fileDir,$ext) = fileparse($vidName,'\..*');
    $fileDir =~ s/\//\\/g;
    $originalFileNameFullPath="$fileDir$name$ext";
  
    # read the media info log, get params for the current video under analysis ($name)
    foreach $mediaLine (@mediaLine){
        if ($mediaLine =~ /$name/) {
            @audioSplit = split(/===/,$mediaLine);
            $originalVidName = $audioSplit[0];
            $originalAudioDur = $audioSplit[1];
            $originalVideoDur = $audioSplit[2];
            $originalFPS = $audioSplit[3];
            $originalBitrate = $audioSplit[4];
            $fixOrKeepVideo = $audioSplit[5];
            $originalVidFolder = $audioSplit[6];
            $originalVidBaseName = $audioSplit[7];
            chomp $originalVidName;
            chomp $originalAudioDur;
            chomp $originalVideoDur;
            chomp $originalFPS;
            chomp $originalBitrate;
            chomp $fixOrKeepVideo;
            chomp $originalVidFolder;
            chomp $originalVidBaseName;
        }
    }

    # logging to file
    say $fh "";
    say $fh "video file = $originalFileNameFullPath";

    # create a temp directory for splitting the videos into images
    $imgDir = $fileDir."images_for_".$name;
    if (-d $imgDir){
        say $fh "error: directory \"$imgDir\" already exists for storing images; skipping";
        next;
    }
    else {
        system("mkdir $imgDir");
    }

    # check there is only one video and one audio stream in the media file
    $numAudStrms = `MediaInfo.exe -f --Inform=General;%AudioCount% \"$vidName\"`;
    $numVidStrms = `MediaInfo.exe -f --Inform=General;%VideoCount% \"$vidName\"`;
    chomp $numAudStrms;
    chomp $numVidStrms;

    if ( ($numVidStrms eq 1) ){
        # use FFmpeg to split the video into individual images
        system("ffmpeg -y -i $vidName -f image2 -q:v 2 $imgDir\\img%08d.jpg");

        # count how many images were produced by the FFmpeg command that split the video
        @dirFileCountFFmpegArr = <$imgDir/*>;
        $dirFileCountFFmpeg = @dirFileCountFFmpegArr;
        chomp $dirFileCountFFmpeg;

        # use mediainfo to get media information
        $audDurMilliSecs = `MediaInfo.exe -f --Inform=Audio;%Duration% \"$vidName\"`;
        $vidDurMilliSecs = `MediaInfo.exe -f --Inform=Video;%Duration% \"$vidName\"`;
        $framesPerSec= `MediaInfo.exe -f --Inform=Video;%FrameRate% \"$vidName\"`;
        $vidBitRateBps = `MediaInfo.exe -f --Inform=Video;%BitRate% \"$vidName\"`;
        chomp $audDurMilliSecs;
        chomp $vidDurMilliSecs;
        chomp $framesPerSec;
        chomp $vidBitRateBps;
        $audDurSecs = ($audDurMilliSecs)/1000;
        $vidDurSecs = ($vidDurMilliSecs)/1000;
        $expectedNumFrames = $originalAudioDur*$framesPerSec;
        chomp $expectedNumFrames;
        #$newTargetFramerate = ($dirFileCountFFmpeg / $expectedNumFrames) * $originalFPS;
        $newTargetFramerate = ($dirFileCountFFmpeg / $originalAudioDur);    # number of images / durationOfOriginal(audio)

        # log the media information obtained from mediainfo
        say $fh "original audio duration = $originalAudioDur seconds";
        say $fh "original video duration = $originalVideoDur seconds";
        say $fh "original frames per second = $originalFPS fps";
        say $fh "original video bitrate = $originalBitrate bps";
        say $fh "mediainfo audio duration = $audDurSecs seconds";
        say $fh "mediainfo video duration = $vidDurSecs seconds";
        say $fh "mediainfo frames per second = $framesPerSec fps";
        say $fh "mediainfo video bitrate = $vidBitRateBps bps";
        say $fh "expected number of frames = $expectedNumFrames frames";
        say $fh "ffmpeg number of frames produced = $dirFileCountFFmpeg frames";
        say $fh "new target framerate = $newTargetFramerate fps";

        # rebuild the video from the images using FFmpeg
        $reconVideoName = $fileDir.$name."_recon".$ext;
        system("ffmpeg -y -f image2 -pattern_type sequence -start_number 00000001 -framerate $newTargetFramerate -i $imgDir\\img%08d.jpg -c:v libx264 -b:v $originalBitrate $reconVideoName");
        
        # delete the directory with all the images as it's not needed now
        say "sleeping ...";
        sleep 60;
        system("rd /s/q $imgDir");
        sleep 60;

        # rename the broken original video in the original folder location
        $brokenVideoName = $originalVidFolder.$originalVidBaseName."\.broken";
        system("move /Y $originalVidName $brokenVideoName");    # renaming (moving) within same folder
        say "sleeping ...";
        sleep 15;

        # rename the video output from the VRT (before FFmpeg split and recon)
        $currentVRTVidName = $fileDir.$name.$ext;
        $newVRTVidName = $fileDir.$name."_vrtOutput".$ext;
        system("move /Y $currentVRTVidName $newVRTVidName");    # renaming (moving) within same folder
        say "sleeping ...";
        sleep 15; 

        # mux the reconstructed video with its audio file
        $reconAudioName = $fileDir.$name.".aac";
        $muxedVidName = $currentVRTVidName;
        system("ffmpeg -y -i $reconVideoName -i $reconAudioName -c:v copy -c:a copy -absf aac_adtstoasc $muxedVidName");
        sleep 15;

        # move the fixed muxed video to the original folder (where the broken renamed video currently is)
        system("move /Y $muxedVidName $originalVidFolder");     # may move between hard-drives
        say "sleeping ...";
        sleep 30;
    }
    else {
        say $fh "error: the media should only have one video stream";
    }
}
close $fh;

sub fileWanted {
    if ($File::Find::name =~ /\.mp4$/){
        push @content, $File::Find::name;
    }
    return;
}


