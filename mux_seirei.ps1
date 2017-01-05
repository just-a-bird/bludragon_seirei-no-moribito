#Requires -Version 5
using namespace System.Collections.Generic
using namespace System.IO

$ErrorActionPreference = "Stop"

try {
    $cmd = "mkvinfo"
    $mkvinfo = Get-Command $cmd
    $cmd = "mkvmerge"
    $mkvmerge = Get-Command $cmd
}
catch {
    $cmd | Write-Debug
    throw "Unable to find $cmd."`
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
function Convert-Attachments([FileInfo[]]$Files, [string]$MimeType ) {
    [List[string]]$commands = @()
    foreach($file in $Files) {
        [void]$commands.AddRange([string[]]@(
            "--attachment-name `"$($file.BaseName)`""
            "--attachment-mime-type `"$MimeType`""
            "--attach-file `"$(Resolve-Path -LiteralPath $file -Relative)`""
        ))
    }
    return $commands
}
function Optimize-Path([string]$Path, [string]$Ext) {
    if ($Ext) {
        $Path = [Path]::ChangeExtension($Path, $Ext)
    }
    return $(Resolve-Path -LiteralPath $Path -Relative)
}
function Convert-Seirei-File([FileInfo]$File,
                             [DirectoryInfo]$OutputDirectory = '.',
                             [string[]]$AttachmentParams) {
    $File = $(Optimize-Path $File)
    Write-Output "`n== Processing file '$File' =="
    $raw_info = (&$mkvinfo $File).Split([Environment]::NewLine)
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
    }
    if ($jpn_audio_tracks.Count -lt 1) {
        Write-Warning "Zero (or fewer) Japanese audio tracks found; defaulting to the second audio track."
        if ($audio_tracks.Count -lt 2) {
            throw "Not enough audio tracks to fall back on; don't know what to do!"
        }
        $jpn_audio_track = $audio_tracks[1]
    } else {
        $jpn_audio_track = $jpn_audio_tracks | Select-Object -First 1
    }
    $jpn_audio_track_id = ($jpn_audio_track.Children | Where-Object {$_.Data.Key -eq 'Track number'} | Select-Object -First 1).SubData.Value
    Write-Output "Jpn Audio Track ID: $jpn_audio_track_id"


    $video_tracks = $segment_tracks | Where-Object {$_.Children | Where-Object { $_.Data.Key -eq 'Track type' -and $_.Data.Value -eq 'video' } }
    if ($video_tracks.Count -gt 1) {
        throw "More than one video track found; don't know what to do!"
    } if ($video_tracks.Count -lt 1) {
        throw "Zero (or fewer) video tracks found; don't know what to do!"
    }
    $video_track = $video_tracks | Select-Object -First 1
    $video_track_id = ($video_track.Children | Where-Object {$_.Data.Key -eq 'Track number'} | Select-Object -First 1).SubData.Value
    Write-Output "    Video Track ID: $video_track_id"

    [List[string]]$mkvmerge_params = @{}
    New-Item -ItemType Directory -Force -Path $OutputDirectory > $null
    $OutputDirectory = $(Optimize-Path $OutputDirectory)
    $OutputPath = [FileInfo][Path]::Combine($OutputDirectory, "$($File.Name)")
    $SubtitlePath = $(Optimize-Path $File '.ass')
    $ChapterPath = $(Optimize-Path $File '.xml')
    [void]$mkvmerge_params.AddRange([string[]]@(
        '--ui-language en'
        "--output `"$OutputPath`""
        "--audio-tracks $jpn_audio_track_id"
        "--default-track $jpn_audio_track_id`:yes"
        "--language $jpn_audio_track_id`:jpn"
        '--no-subtitles'
        "--language $video_track_id`:jpn"
        "`"(`" `"$File`" `")`""
        '--language 0:eng'
        '--track-name "0:Signs & Dialogue (SSA)"'
        "`"(`" `"$SubtitlePath`" `")`""
    ))
    [void]$mkvmerge_params.AddRange($AttachmentParams)
    [void]$mkvmerge_params.AddRange([string[]]@(
        "--chapters `"$ChapterPath`""
        "--track-order 0:$video_track_id,0:$jpn_audio_track_id,1:0"
    ))
    $mkvmerge_exec = "$mkvmerge $($mkvmerge_params -join ' ')"
    $mkvmerge_exec | Write-Verbose
    Invoke-Expression $mkvmerge_exec
}
$AttachmentParams = Convert-Attachments (Get-ChildItem -Recurse '*.ttf') -MimeType 'application/x-truetype-font'
$outdir = '.\Edited'
Remove-Item -Force -Recurse $outdir
Get-Item '*.mkv' | ForEach-Object{Convert-Seirei-File -File $_ -OutputDirectory $outdir -AttachmentParams $AttachmentParams}