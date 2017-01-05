#Requires -Version 5
using namespace System.Collections.Generic

$ErrorActionPreference = "Stop"

try {
    $mkvinfo = Get-Command "mkvinfo"
}
catch {
   throw 'Unable to find mkvinfo.'`
       + ' Please install MKVToolNix and ensure that'`
       + ' it is referenced in your PATH.'
}

$regex = [regex]('^(?<Indent>\|? *\+) (?:(?<DataKey>.*?)'`
                + '(?:: (?<DataValue>.*?))?)(?: \((?<SubDataKey>.*?)'`
                + '(?:: (?<SubDataValue>.*?))?\))?$')

class Node {
    [string]$RawLine
    [List[Node]]$Children = @()
    [int]$Level
    [KeyValuePair[string,string]]$Data
    [KeyValuePair[string,string]]$SubData
    [string] ToString() {
        return "$($this.Level)> $($this.Data) ($($this.SubData))"
    }
    [string] ShortString() {
        return "$($this.Level)>'$($this.Data.Key)'"
    }
}

$file = Get-Item "01 - Balsa the Female Bodyguard.mkv"
function RemuxFile([System.IO.FileInfo]$file) {

}
Write-Output "Processing file '$(Resolve-Path -LiteralPath $file -Relative)'"
$raw_info = (&$mkvinfo $file).Split([Environment]::NewLine)
[Stack[Node]]$stack = @{}
[Node]$root = @{Level=-1}
$stack.Push($root)
foreach ($line in $raw_info) {
    [Node]$node = @{}
    $node.RawLine = $line
    $match = $regex.Match($line)
    $node.Data = [KeyValuePair[string,string]]::new(
        $match.Groups['DataKey'].Value,
        $match.Groups['DataValue'].Value
    )
    $node.SubData = [KeyValuePair[string,string]]::new(
        $match.Groups['SubDataKey'].Value,
        $match.Groups['SubDataValue'].Value
    )
    $node.Level = ($match.Groups['Indent'].Value).IndexOf('+')
    while ($true) {
        $head = $stack.Peek()
        if ($head.Level -eq $node.Level - 1) {
            # $node is a child of $head
            $head.Children.Add($node)
            $stack.Push($node)
            break
        } elseif ($head.Level -ge $node.Level) {
            # $node is not a child of $head
            $stack.Pop() > $null
            continue
        } else {
            # $node skips its parent
            throw "Unexpected level of node: $node"
        }
    }
}
$segment_head = $root.Children | Where-Object {$_.Data.Key.StartsWith("Segment,")} | Select-Object -First 1
$segment_tracks_head = $segment_head.Children | Where-Object {$_.Data.Key -eq "Segment tracks"} | Select-Object -First 1
$segment_tracks = $segment_tracks_head.Children | Where-Object {$_.Data.Key -eq "A track"}

$audio_tracks = $segment_tracks | Where-Object {$_.Children | Where-Object { $_.Data.Key -eq 'Track type' -and $_.Data.Value -eq 'audio' } }

$jpn_audio_tracks = $audio_tracks | Where-Object {$_.Children | Where-Object { $_.Data.Key -eq 'Language' -and $_.Data.Value -eq 'jpn' }}
if ($jpn_audio_tracks.Count -gt 1) {
    throw "More than one Japanese audio track found; don't know what to do!"
} if ($jpn_audio_tracks.Count -lt 1) {
    throw "Zero (or fewer) Japanese audio tracks found; don't know what to do!"
}
$jpn_audio_track = $jpn_audio_tracks | Select-Object -First 1
$jpn_audio_track_id = ($jpn_audio_track.Children | Where-Object {$_.Data.Key -eq 'Track number'} | Select-Object -First 1).SubData.Value
Write-Output "Japanese audio ID: $jpn_audio_track_id"


$video_tracks = $segment_tracks | Where-Object {$_.Children | Where-Object { $_.Data.Key -eq 'Track type' -and $_.Data.Value -eq 'video' } }
if ($video_tracks.Count -gt 1) {
    throw "More than one video track found; don't know what to do!"
} if ($video_tracks.Count -lt 1) {
    throw "Zero (or fewer) video tracks found; don't know what to do!"
}
$video_track = $video_tracks | Select-Object -First 1
$video_track_id = ($video_track.Children | Where-Object {$_.Data.Key -eq 'Track number'} | Select-Object -First 1).SubData.Value
Write-Output "         Video ID: $video_track_id"
