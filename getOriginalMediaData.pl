#!/usr/bin/perl -w

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
my $logFile;
my $fh;
my $audDurMilliSecs;
my $vidDurMilliSecs;
my $audDurSecs;
my $vidDurSecs;
my $numAudStrms;
my $numVidStrms;
my $fps;
my $bitrate;
my $allStr;
my $errStr;
my @allArr;
my $audVidDiff;
my @splitter;
my $perlFilenameBase;

##### user MUST initialise these #####
# common folder for perl and log files; the user must create the folder 'C:\iSurveyMediaFix' and put the perl files in it
my $iSurveyPerlFixFolder = "C:\\iSurveyMediaFix";
# top level folder of original broken videos; this folder must exist and contain broken videos in itself and/or subdirs
my $vidOriginalsFolder = "F:\\VIDEO_FIX\\iSurvey_test4\\orig";
# folder where all videos to be VRT'd are copied to; user must create this folder manually
my $vidToBeFixedUsingVRTFolder = "H:\\toBeFixedUsingVRT";      
# folder containing VRT fixed videos; user must create this folder manually and use this as the output folder for the VRT
my $vidHaveBeenFixedUsingVRTFolder = "H:\\toBeFixedUsingVRT\\fixedByVRT";      
# max time difference (secs) allowed between video and audio duration
my $maxTimeDiffAllowed = 3;         # test two videos
#my $maxTimeDiffAllowed = 270;     # test one video
##### end initialise #####

# checking the user specified folders 
if (-d $iSurveyPerlFixFolder){
    say "using folder '$iSurveyPerlFixFolder'";
}
else {
    say "Error: folder '$iSurveyPerlFixFolder' doesn't exist, please create it.";
    exit;
}
if (-d $vidOriginalsFolder){
    say "using folder '$vidOriginalsFolder'";
}
else {
    say "Error: folder '$vidOriginalsFolder' doesn't exist, please point to the original broken videos.";
    exit;
}
if (-d $vidToBeFixedUsingVRTFolder){
    say "using folder '$vidToBeFixedUsingVRTFolder'";
}
else {
    say "Error: folder '$vidToBeFixedUsingVRTFolder' doesn't exist, please create it.";
    exit;
}
if (-d $vidHaveBeenFixedUsingVRTFolder){
    say "using folder '$vidHaveBeenFixedUsingVRTFolder'";
}
else {
    say "Error: folder '$vidHaveBeenFixedUsingVRTFolder' doesn't exist, please create it.";
    exit;
}

# find all MP4 files from current and sub directories
find( \&fileWanted, $vidOriginalsFolder); 

foreach my $vidName (@content) {
    # get filename, directory and extension of the found video
    ($name,$fileDir,$ext) = fileparse($vidName,'\..*');
    $fileDir =~ s/\//\\/g;
    $originalFileNameFullPath="$fileDir$name$ext";

    # check there is only one video and one audio stream in the media file
    $numAudStrms = `MediaInfo.exe -f --Inform=General;%AudioCount% \"$vidName\"`;
    $numVidStrms = `MediaInfo.exe -f --Inform=General;%VideoCount% \"$vidName\"`;
    chomp $numAudStrms;
    chomp $numVidStrms;

    if ( ($numVidStrms == 1) ) {
        # use mediainfo to get the media information
        $audDurMilliSecs = `MediaInfo.exe -f --Inform=Audio;%Duration% \"$vidName\"`;
        $vidDurMilliSecs = `MediaInfo.exe -f --Inform=Video;%Duration% \"$vidName\"`;
        $fps = `MediaInfo.exe -f --Inform=Video;%FrameRate% \"$vidName\"`;
        $bitrate = `MediaInfo.exe -f --Inform=Video;%BitRate% \"$vidName\"`;
        chomp $audDurMilliSecs;
        chomp $vidDurMilliSecs;
        chomp $fps;
        chomp $bitrate;
        $audDurSecs = $audDurMilliSecs / 1000;
        $vidDurSecs = $vidDurMilliSecs / 1000;
        $audVidDiff = abs( $audDurSecs - $vidDurSecs );

        # logging all media data
        $allStr = "$originalFileNameFullPath===$audDurSecs===$vidDurSecs===$fps===$bitrate";
        if ($audVidDiff > $maxTimeDiffAllowed){
            $allStr = $allStr."===fixMe";
        }
        else {
            $allStr = $allStr."===keepMe";
        }
        $allStr = $allStr."===$fileDir";
        $allStr = $allStr."===$name";
        push(@allArr, $allStr);
    }

    else {
        $errStr = "error: $originalFileNameFullPath the media should only have one video stream";
        push(@allArr, $errStr);
    }
}

# write log files for all media data
$perlFilenameBase=basename($0);
$perlFilenameBase=~s/\.pl//;
$logFile = $iSurveyPerlFixFolder."\\$perlFilenameBase\.log";
open ($fh, '>', $logFile) or die ("Could not open file '$logFile' $!");
foreach (@allArr){
    say $fh $_;
}
close $fh;

# write the folder the user specified in the initialise section to a .dat file
# this means it is only necessary for the user to initialise parameters in one (this) file
$logFile = $iSurveyPerlFixFolder."\\vrtFixedVideoFolder\.dat";
open ($fh, '>', $logFile) or die ("Could not open file '$logFile' $!");
say $fh $vidHaveBeenFixedUsingVRTFolder;
close $fh;

# copy videos to be VRT fixed to the user specified $vidToBeFixedUsingVRTFolder
foreach (@allArr){
    if ($_ =~ m/fixMe/){
        @splitter = split(/===/, $_);
        $originalFileNameFullPath = $splitter[0];
        $fileDir = $splitter[6];
        $name = $splitter[7];
        say "copying $originalFileNameFullPath to $vidToBeFixedUsingVRTFolder ...";
        system("copy /Y $originalFileNameFullPath $vidToBeFixedUsingVRTFolder"); 
        say "extracting the audio ...";
        system("ffmpeg -y -i $originalFileNameFullPath -vn -c:a copy $fileDir$name\.aac");
        say "moving the extracted audio to $vidHaveBeenFixedUsingVRTFolder";
        system("move /Y $fileDir$name\.aac $vidHaveBeenFixedUsingVRTFolder");
    }
}

# find files with ".mp4" at the end of their names
sub fileWanted {
    if ($File::Find::name =~ /\.mp4$/){
        push @content, $File::Find::name;
    }
    return;
}
